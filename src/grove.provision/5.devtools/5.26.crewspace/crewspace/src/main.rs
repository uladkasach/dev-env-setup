//! .what = crewspace — read and place windows across COSMIC workspaces
//!
//! .why  = on COSMIC (wayland) a client cannot pick the workspace it opens on,
//!         so every crew window lands on whichever workspace is active. this
//!         speaks the compositor's own protocols — the ones its panel and
//!         workspace switcher use — to list windows with their workspace, and
//!         to move a window onto a named workspace.
//!
//! usage:
//!   crewspace get [--debug]
//!   crewspace set --match <part of title or app_id> --workspace <name> [--force] [--debug]
//!
//!   --debug  print every event the compositor sends on each window's cosmic handle
//!
//! exit: 0 ok · 1 malfunction · 2 constraint (bad args, no match, unsupported)
//!
//! .note = the window record is hand-rolled rather than the toolkit's
//!         ToplevelInfoState. measured 2026-10-11 on cosmic-comp (manager v4,
//!         info v3): the compositor sends a window's ext `done` BEFORE its cosmic
//!         `state`, and the toolkit commits a window only on an ext `done` that
//!         follows cosmic state — so it listed zero windows while a raw listener
//!         saw five. here each half is merged as it arrives, with no order assumed.

use std::collections::HashSet;
use std::sync::OnceLock;

/// set by `--debug`: print every event the compositor sends on a window's cosmic handle
static DEBUG: OnceLock<bool> = OnceLock::new();

fn is_debug() -> bool {
    DEBUG.get().copied().unwrap_or(false)
}

use cosmic_client_toolkit::{
    cosmic_protocols::{
        toplevel_info::v1::client::{zcosmic_toplevel_handle_v1, zcosmic_toplevel_info_v1},
        toplevel_management::v1::client::zcosmic_toplevel_manager_v1,
    },
    sctk::{
        self,
        output::{OutputHandler, OutputState},
        registry::{ProvidesRegistryState, RegistryState},
    },
    toplevel_management::{ToplevelManagerHandler, ToplevelManagerState},
    wayland_client::{
        globals::registry_queue_init, protocol::wl_output, Connection, Dispatch, EventQueue,
        Proxy, QueueHandle, WEnum,
    },
    wayland_protocols::ext::{
        foreign_toplevel_list::v1::client::{
            ext_foreign_toplevel_handle_v1 as ext_handle, ext_foreign_toplevel_list_v1 as ext_list,
        },
        workspace::v1::client::ext_workspace_handle_v1,
    },
    workspace::{Workspace, WorkspaceHandler, WorkspaceState},
};

/// the protocol's enum value for `move_to_ext_workspace`
const CAP_MOVE_TO_EXT_WORKSPACE: u32 = 8;

/// one window, merged from the ext list (title, app_id) and the cosmic handle (workspaces)
#[derive(Clone)]
struct Win {
    ext: ext_handle::ExtForeignToplevelHandleV1,
    cosmic: Option<zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1>,
    title: String,
    app_id: String,
    workspaces: HashSet<ext_workspace_handle_v1::ExtWorkspaceHandleV1>,
    closed: bool,
}

struct App {
    output_state: OutputState,
    registry_state: RegistryState,
    ws: WorkspaceState,
    mgr: Option<ToplevelManagerState>,
    caps: Vec<u32>,
    cosmic_info: Option<zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1>,
    wins: Vec<Win>,
}

impl App {
    fn win_by_ext(&mut self, h: &ext_handle::ExtForeignToplevelHandleV1) -> Option<&mut Win> {
        self.wins.iter_mut().find(|w| &w.ext == h)
    }
    fn win_by_cosmic(&mut self, h: &zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1) -> Option<&mut Win> {
        self.wins.iter_mut().find(|w| w.cosmic.as_ref() == Some(h))
    }
}

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    sctk::registry_handlers!(OutputState);
}

impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}

impl WorkspaceHandler for App {
    fn workspace_state(&mut self) -> &mut WorkspaceState {
        &mut self.ws
    }
    fn done(&mut self) {}
}

impl ToplevelManagerHandler for App {
    fn toplevel_manager_state(&mut self) -> &mut ToplevelManagerState {
        self.mgr.as_mut().expect("manager events imply a bound manager")
    }
    fn capabilities(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        capabilities: Vec<WEnum<zcosmic_toplevel_manager_v1::ZcosmicToplelevelManagementCapabilitiesV1>>,
    ) {
        self.caps = capabilities
            .into_iter()
            .map(|c| match c {
                WEnum::Value(v) => v as u32,
                WEnum::Unknown(u) => u,
            })
            .collect();
    }
}

// ── the ext list: one handle per window, with title and app_id ──────────
impl Dispatch<ext_list::ExtForeignToplevelListV1, ()> for App {
    fn event(app: &mut Self, _: &ext_list::ExtForeignToplevelListV1, e: ext_list::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let ext_list::Event::Toplevel { toplevel } = e {
            let cosmic = app.cosmic_info.as_ref().map(|i| i.get_cosmic_toplevel(&toplevel, qh, ()));
            app.wins.push(Win {
                ext: toplevel,
                cosmic,
                title: String::new(),
                app_id: String::new(),
                workspaces: HashSet::new(),
                closed: false,
            });
        }
    }
    cosmic_client_toolkit::wayland_client::event_created_child!(App, ext_list::ExtForeignToplevelListV1, [
        ext_list::EVT_TOPLEVEL_OPCODE => (ext_handle::ExtForeignToplevelHandleV1, ())
    ]);
}

impl Dispatch<ext_handle::ExtForeignToplevelHandleV1, ()> for App {
    fn event(app: &mut Self, h: &ext_handle::ExtForeignToplevelHandleV1, e: ext_handle::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        let Some(w) = app.win_by_ext(h) else { return };
        match e {
            ext_handle::Event::Title { title } => w.title = title,
            ext_handle::Event::AppId { app_id } => w.app_id = app_id,
            ext_handle::Event::Closed => w.closed = true,
            _ => {}
        }
    }
}

// ── the cosmic half: which workspaces each window sits on ───────────────
impl Dispatch<zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1, ()> for App {
    fn event(_: &mut Self, _: &zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1, _: zcosmic_toplevel_info_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {}
    cosmic_client_toolkit::wayland_client::event_created_child!(App, zcosmic_toplevel_info_v1::ZcosmicToplevelInfoV1, [
        zcosmic_toplevel_info_v1::EVT_TOPLEVEL_OPCODE => (zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1, ())
    ]);
}

impl Dispatch<zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1, ()> for App {
    fn event(app: &mut Self, h: &zcosmic_toplevel_handle_v1::ZcosmicToplevelHandleV1, e: zcosmic_toplevel_handle_v1::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if is_debug() {
            // stdout, never stderr: rhx drops a skill's stderr on exit 0
            println!("debug: cosmic handle {:?} event {:?}", h.id(), e);
        }
        let Some(w) = app.win_by_cosmic(h) else { return };
        match e {
            zcosmic_toplevel_handle_v1::Event::ExtWorkspaceEnter { workspace } => {
                w.workspaces.insert(workspace);
            }
            zcosmic_toplevel_handle_v1::Event::ExtWorkspaceLeave { workspace } => {
                w.workspaces.remove(&workspace);
            }
            _ => {}
        }
    }
}

sctk::delegate_output!(App);
sctk::delegate_registry!(App);
cosmic_client_toolkit::delegate_workspace!(App);
cosmic_client_toolkit::delegate_toplevel_manager!(App);

/// the workspace names a window sits on, joined
fn workspaces_of(app: &App, w: &Win) -> String {
    let mut names: Vec<String> = w
        .workspaces
        .iter()
        .filter_map(|h| app.ws.workspace_info(h).map(|x| x.name.clone()))
        .collect();
    names.sort();
    if names.is_empty() { "-".into() } else { names.join(",") }
}

/// every workspace, in on-screen order
fn workspaces_sorted(app: &App) -> Vec<&Workspace> {
    let mut all: Vec<&Workspace> = app.ws.workspaces().collect();
    all.sort_by(|a, b| a.coordinates.cmp(&b.coordinates));
    all
}

fn live_wins(app: &App) -> Vec<Win> {
    app.wins.iter().filter(|w| !w.closed).cloned().collect()
}

// ── the placement record: which workspace each crew last sat on ─────────
//
// a crew window carries the wayland app_id `crew.<tree>` (term.open --class),
// so a live window names its own crew. the record keeps that fact past the
// window's death: a crash takes every window, and only this file remembers
// where the human had put each one.

/// the app_id prefix a crew window carries
const CREW_APP_PREFIX: &str = "crew.";

fn store_path() -> std::path::PathBuf {
    let base = std::env::var_os("XDG_STATE_HOME")
        .map(std::path::PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| std::path::PathBuf::from(h).join(".local/state")))
        .unwrap_or_else(|| std::path::PathBuf::from("/tmp"));
    base.join("rhachet/crewspace/placement.tsv")
}

/// .what = the key a workspace is recorded under: its id, else its name
/// .note = measured 2026-10-12, cosmic-comp 1dfc948 sends NO ext_workspace id,
///         so every key is `name:N` today. the id path is kept for the build
///         that sends one. until then a restore keeps ORDER, not numbers:
///         `get --order` lists crews in recorded workspace order, and a
///         restore re-places them in that order, each onto the next empty one.
/// .why  = a workspace NAME is its position, and COSMIC renumbers on every
///         change: measured 2026-10-11, one felled crew emptied a workspace,
///         COSMIC dropped it, and every crew after it shifted down a number —
///         so a name-keyed record pointed each crew at its neighbor's
///         workspace. the ext_workspace `id` survives the renumber.
fn ws_key(w: &Workspace) -> String {
    w.id.clone().unwrap_or_else(|| format!("name:{}", w.name))
}

/// the keys of every workspace a window sits on
fn keys_of(app: &App, w: &Win) -> Vec<String> {
    w.workspaces.iter().filter_map(|h| app.ws.workspace_info(h).map(ws_key)).collect()
}

/// tree → workspace key, from the record (absent file = empty record)
fn store_read() -> std::collections::BTreeMap<String, String> {
    std::fs::read_to_string(store_path())
        .unwrap_or_default()
        .lines()
        .filter_map(|l| {
            let mut parts = l.split('\t');
            Some((parts.next()?.to_string(), parts.next()?.to_string()))
        })
        .collect()
}

fn store_write(map: &std::collections::BTreeMap<String, String>) {
    let path = store_path();
    if let Some(dir) = path.parent() {
        let _ = std::fs::create_dir_all(dir);
    }
    let body: String = map.iter().map(|(k, v)| format!("{k}\t{v}\n")).collect();
    let _ = std::fs::write(path, body);
}

/// the crew a window belongs to, from its app_id
fn crew_of(w: &Win) -> Option<&str> {
    w.app_id.strip_prefix(CREW_APP_PREFIX)
}

/// fold every live crew window's current workspace into the record
fn record_crews(app: &App) -> usize {
    let mut map = store_read();
    let mut seen = 0;
    for w in live_wins(app) {
        let Some(crew) = crew_of(&w) else { continue };
        let Some(key) = keys_of(app, &w).into_iter().next() else { continue };
        map.insert(crew.to_string(), key);
        seen += 1;
    }
    store_write(&map);
    seen
}

/// pump the queue with wall-clock gaps — cosmic-comp answers on its refresh tick
fn settle(app: &mut App, queue: &mut EventQueue<App>, ticks: u32) {
    for _ in 0..ticks {
        std::thread::sleep(std::time::Duration::from_millis(50));
        if queue.roundtrip(app).is_err() { break; }
    }
}

/// .what = move a crew's window onto the crew's own workspace, in the BACKGROUND
/// .why  = one workspace per crew, and the human's focus untouched
///         (rule.forbid.move-the-human-focus). a window must be born on the
///         active workspace, so it is moved off the instant it appears.
///         measured 2026-10-12: move_to_ext_workspace moved a window to a
///         background workspace, the active workspace never changed, and
///         cosmic-comp handed activation back to a window on the human's own
///         workspace. the brief flash on birth is accepted by the human.
/// .target = the crew's recorded workspace, if it still exists and no OTHER
///         crew holds it; else the first workspace with no window at all.
///         the active workspace is never a target — that is the human's.
fn cmd_place(app: &mut App, crew: &str, args: &[String], conn: &Connection, queue: &mut EventQueue<App>) -> i32 {
    use ext_workspace_handle_v1::State;
    let app_id = format!("{CREW_APP_PREFIX}{crew}");

    // --await: the window is born while this runs, so watch for it
    let await_ticks = if args.iter().any(|a| a == "--await") { 400 } else { 0 };
    let mut found = live_wins(app).into_iter().find(|w| w.app_id == app_id && w.cosmic.is_some());
    let mut ticks = 0;
    while found.is_none() && ticks < await_ticks {
        settle(app, queue, 1);
        ticks += 1;
        found = live_wins(app).into_iter().find(|w| w.app_id == app_id && w.cosmic.is_some());
    }
    let Some(win) = found else {
        eprintln!("✋ ConstraintError: no window with app_id '{app_id}' appeared");
        return 2;
    };

    // pick the target: recorded, else first empty — never the active one
    let wins = live_wins(app);
    let held_by_any_other = |key: &str| {
        wins.iter().any(|w| w.ext != win.ext && keys_of(app, w).iter().any(|k| k == key))
    };
    let candidates: Vec<Workspace> = workspaces_sorted(app)
        .into_iter()
        .filter(|w| !w.state.contains(State::Active))
        .cloned()
        .collect();
    let recorded = store_read().get(crew).cloned();
    let (target, why) = match recorded.and_then(|k| candidates.iter().find(|w| ws_key(w) == k).cloned()) {
        // ⚠️ a recorded key may be a NAME (cosmic-comp 1dfc948 sends no
        //    ext_workspace id), and a name drifts on renumber — so the record is
        //    trusted only where that workspace is empty, never where it now
        //    holds a window of anyone's
        Some(ws) if !held_by_any_other(&ws_key(&ws)) => (Some(ws), "its recorded workspace"),
        _ => (
            candidates.iter().find(|w| !held_by_any_other(&ws_key(w))).cloned(),
            "the first empty workspace",
        ),
    };
    let Some(target) = target else {
        eprintln!("✋ ConstraintError: no empty background workspace for crew '{crew}' — it stays where it opened");
        return 2;
    };

    // already there? then naught to do
    if keys_of(app, &win).iter().any(|k| *k == ws_key(&target)) {
        println!("🪐 git.crew.space set --crew {crew} → already on workspace {}", target.name);
        return 0;
    }

    let Some(output) = app
        .ws
        .workspace_groups()
        .find(|g| g.workspaces.contains(&target.handle))
        .and_then(|g| g.outputs.first().cloned())
    else {
        eprintln!("💥 MalfunctionError: workspace '{}' has no output", target.name);
        return 1;
    };
    let (Some(mgr), Some(ct)) = (app.mgr.as_ref(), win.cosmic.as_ref()) else {
        eprintln!("💥 MalfunctionError: no toplevel manager or cosmic handle");
        return 1;
    };
    mgr.manager.move_to_ext_workspace(ct, &target.handle, &output);
    let _ = conn.flush();
    settle(app, queue, 10);

    // verify by re-read; a sent request proves naught
    //    ⚠️ by HANDLE: the move can empty the source workspace, and COSMIC
    //       renumbers when it drops it — the target's name moves under us
    let landed = app
        .wins
        .iter()
        .find(|w| w.ext == win.ext)
        .map(|w| verdict_landed(&seen_of(app, w), &target.handle))
        .unwrap_or(false);
    let target_now = name_now(app, &target);
    if !landed {
        eprintln!("💥 MalfunctionError: move of crew '{crew}' to workspace {target_now} did not land");
        return 1;
    }
    record_crews(app);
    println!("🪐 git.crew.space set --crew {crew} → workspace {target_now} ({why})");
    0
}

/// one workspace a window sits on, as the re-read after a move sees it
struct WsSeen<H> {
    handle: H,
    /// the name the re-read shows. the verdict never reads it — it is carried
    /// so a clamp can state the renumber it must survive
    #[allow(dead_code)]
    name: String,
}

/// .what = did the window land on the workspace it was asked onto?
/// .why  = keyed on the workspace HANDLE, never its name. a name IS a position,
///         and COSMIC renumbers on every change: measured 2026-10-19 (10kpm
///         subdirector), a move onto workspace 5 emptied the source, COSMIC
///         dropped it, and the target read `4` on the re-read. a name-keyed
///         verdict printed 0/1 over a move that landed — and, the mirror case,
///         would print 1/1 over a window that sits on the neighbor that
///         inherited the name. the handle survives the renumber.
fn verdict_landed<H: PartialEq>(after: &[WsSeen<H>], target: &H) -> bool {
    after.iter().any(|w| &w.handle == target)
}

/// every workspace a window sits on, with its handle and its CURRENT name
fn seen_of(app: &App, w: &Win) -> Vec<WsSeen<ext_workspace_handle_v1::ExtWorkspaceHandleV1>> {
    w.workspaces
        .iter()
        .filter_map(|h| {
            app.ws
                .workspace_info(h)
                .map(|x| WsSeen { handle: h.clone(), name: x.name.clone() })
        })
        .collect()
}

/// the name a workspace carries NOW — after any renumber since it was picked
fn name_now(app: &App, ws: &Workspace) -> String {
    app.ws
        .workspace_info(&ws.handle)
        .map(|x| x.name.clone())
        .unwrap_or_else(|| ws.name.clone())
}

// ── the view: a plain snapshot of what get reads, from the compositor or a capture ──
//
// .why = every read decision (a filter, the last occupied workspace, the
//        bottom target of `set --workspace last`) is made on this plain
//        snapshot, never on live handles. so each one is clamped against a
//        captured get (`--from-capture`), with no compositor in reach.

/// one workspace, in on-screen order
#[derive(Clone, Debug)]
struct WsRow {
    name: String,
    coords: String,
    active: bool,
}

/// one live window, with the names of the workspaces it sits on
#[derive(Clone, Debug)]
struct WinRow {
    ws: Vec<String>,
    app_id: String,
    title: String,
}

#[derive(Clone, Debug)]
struct View {
    can_move: bool,
    mgr_version: u32,
    caps: Vec<u32>,
    workspaces: Vec<WsRow>,
    wins: Vec<WinRow>,
}

fn view_of(app: &App) -> View {
    use ext_workspace_handle_v1::State;
    let mut wins: Vec<WinRow> = live_wins(app)
        .iter()
        .map(|w| {
            let mut ws: Vec<String> = w
                .workspaces
                .iter()
                .filter_map(|h| app.ws.workspace_info(h).map(|x| x.name.clone()))
                .collect();
            ws.sort();
            WinRow { ws, app_id: w.app_id.clone(), title: w.title.clone() }
        })
        .collect();
    wins.sort_by(|a, b| a.app_id.cmp(&b.app_id).then(a.title.cmp(&b.title)));
    View {
        can_move: app.caps.contains(&CAP_MOVE_TO_EXT_WORKSPACE),
        mgr_version: app.mgr.as_ref().map(|m| m.manager.version()).unwrap_or(0),
        caps: app.caps.clone(),
        workspaces: workspaces_sorted(app)
            .into_iter()
            .map(|w| WsRow {
                name: w.name.clone(),
                coords: format!("{:?}", w.coordinates),
                active: w.state.contains(State::Active),
            })
            .collect(),
        wins,
    }
}

/// .what = one field of a capture line, with every control byte dropped
/// .why  = a window names its own title, so a tab or a newline in it would
///         split the field or the row the reader parses
fn capture_field(s: &str) -> String {
    s.chars().filter(|c| !c.is_control()).collect()
}

/// .what = the view as a capture — the exact format `view_from_capture` reads
/// .why  = a caller that needs the live view as data (a terminal snapshot that
///         joins each window to its workspace) reads this, not the tree
fn render_capture(view: &View) -> String {
    let mut out = String::new();
    out.push_str(&format!("move\t{}\t{}\n", if view.can_move { 1 } else { 0 }, view.mgr_version));
    for w in &view.workspaces {
        out.push_str(&format!(
            "ws\t{}\t{}\t{}\n",
            capture_field(&w.name),
            capture_field(&w.coords),
            if w.active { 1 } else { 0 }
        ));
    }
    for w in &view.wins {
        let ws = if w.ws.is_empty() { "-".to_string() } else { capture_field(&w.ws.join(",")) };
        out.push_str(&format!("win\t{}\t{}\t{}\n", ws, capture_field(&w.app_id), capture_field(&w.title)));
    }
    out
}

/// .what = a captured get, as tab-separated lines
///   move  <0|1>  <manager version>
///   ws    <name> <coords>  <0|1 active>
///   win   <ws names, comma-joined, or ->  <app_id>  <title>
/// lines that start with `#` and blank lines are skipped
fn view_from_capture(body: &str) -> Result<View, String> {
    let mut view = View { can_move: false, mgr_version: 0, caps: Vec::new(), workspaces: Vec::new(), wins: Vec::new() };
    for (i, line) in body.lines().enumerate() {
        if line.trim().is_empty() || line.starts_with('#') { continue; }
        let f: Vec<&str> = line.split('\t').collect();
        match (f.first().copied(), f.len()) {
            (Some("move"), 3) => {
                view.can_move = f[1] == "1";
                view.mgr_version = f[2].parse().map_err(|_| format!("line {}: manager version is not a number", i + 1))?;
            }
            (Some("ws"), 4) => view.workspaces.push(WsRow { name: f[1].into(), coords: f[2].into(), active: f[3] == "1" }),
            (Some("win"), 4) => view.wins.push(WinRow {
                ws: if f[1] == "-" { Vec::new() } else { f[1].split(',').map(String::from).collect() },
                app_id: f[2].into(),
                title: f[3].into(),
            }),
            _ => return Err(format!("line {}: expected `move`, `ws`, or `win` with tab-separated fields", i + 1)),
        }
    }
    Ok(view)
}

/// which windows a read or a move is about
#[derive(Clone, Debug)]
enum Filter {
    /// a part of the title or the app_id (`--match`)
    Part(String),
    /// the exact app_id (`--app-id`; `--tree` resolves to it, as `crew.<tree>`)
    AppId(String),
}

impl Filter {
    fn holds(&self, w: &WinRow) -> bool {
        match self {
            Filter::Part(p) => w.title.contains(p.as_str()) || w.app_id.contains(p.as_str()),
            Filter::AppId(a) => &w.app_id == a,
        }
    }
    fn label(&self) -> String {
        match self {
            Filter::Part(p) => format!("--match {p}"),
            Filter::AppId(a) => format!("--app-id {a}"),
        }
    }
}

fn filter_of(args: &[String]) -> Option<Filter> {
    if let Some(a) = arg(args, "--app-id") {
        return Some(Filter::AppId(a));
    }
    arg(args, "--match").map(Filter::Part)
}

/// .what = the on-screen index of the lowest workspace that holds a window,
///         among the windows `skip` does not exclude
/// .why  = "the bottom" a human reads is the last workspace with aught on it
fn last_occupied_index(view: &View, skip: &dyn Fn(&WinRow) -> bool) -> Option<usize> {
    view.wins
        .iter()
        .filter(|w| !skip(w))
        .flat_map(|w| w.ws.iter())
        .filter_map(|n| view.workspaces.iter().position(|x| &x.name == n))
        .max()
}

/// .what = the workspace `set --workspace last` moves onto: the first one past
///         the last workspace another window holds
/// .why  = COSMIC keeps one empty workspace past the last occupied one, and
///         renumbers when a move empties the source. a count from the human
///         drifts by one on that renumber; this target is resolved fresh from
///         the read, and the move verdict reads by handle, so it lands at the
///         bottom whatever the renumber does.
fn bottom_target(view: &View, skip: &dyn Fn(&WinRow) -> bool) -> Option<String> {
    if view.workspaces.is_empty() {
        return None;
    }
    let i = match last_occupied_index(view, skip) {
        Some(i) => (i + 1).min(view.workspaces.len() - 1),
        None => 0,
    };
    Some(view.workspaces[i].name.clone())
}

fn ws_label(w: &WinRow) -> String {
    if w.ws.is_empty() { "-".into() } else { w.ws.join(",") }
}

/// .what = the get render, whole or filtered, and its exit code
/// .why  = a filtered read prints only the windows it asked about, so a
///         verify after a move reads one line rather than every workspace
fn render_get(view: &View, filter: Option<&Filter>, debug_line: Option<String>) -> (String, i32) {
    let mut out = String::new();
    let mut line = |s: String| { out.push_str(&s); out.push('\n'); };
    let head = filter.map(|f| format!(" {}", f.label())).unwrap_or_default();
    line(format!("🪐 git.crew.space get{head}"));
    line(format!("   ├─ move advertised: {} (manager v{}, caps {:?})", view.can_move, view.mgr_version, view.caps));
    if let Some(d) = debug_line { line(d); }
    let last = last_occupied_index(view, &|_| false)
        .map(|i| view.workspaces[i].name.clone())
        .unwrap_or_else(|| "none".into());
    line(format!("   ├─ last occupied: {last}"));
    let Some(f) = filter else {
        line("   ├─ workspaces".into());
        for w in &view.workspaces {
            let active = if w.active { " ← active" } else { "" };
            line(format!("   │  ├─ {:<6} coords {}{}", w.name, w.coords, active));
        }
        line("   └─ windows".into());
        for w in &view.wins {
            line(format!("      ├─ ws {:<6} app {:<12} {}", ws_label(w), w.app_id, w.title));
        }
        return (out, 0);
    };
    let hits: Vec<&WinRow> = view.wins.iter().filter(|w| f.holds(w)).collect();
    line(format!("   └─ windows: {} of {} hold it", hits.len(), view.wins.len()));
    if hits.is_empty() {
        line("      └─ (none)".into());
        return (out, 2);
    }
    for (i, w) in hits.iter().enumerate() {
        let glyph = if i + 1 == hits.len() { "└─" } else { "├─" };
        line(format!("      {glyph} ws {:<6} app {:<12} {}", ws_label(w), w.app_id, w.title));
    }
    (out, 0)
}

/// .what = run get or set against a captured view; set only plans
/// .why  = the clamp seam: every read decision is exercised with no compositor,
///         and no window can move
fn run_capture(args: &[String], path: &str) -> i32 {
    let body = match std::fs::read_to_string(path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("✋ ConstraintError: could not read capture '{path}': {e}");
            return 2;
        }
    };
    let view = match view_from_capture(&body) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("✋ ConstraintError: capture '{path}' is malformed — {e}");
            return 2;
        }
    };
    let filter = filter_of(args);
    match args.get(1).map(String::as_str) {
        Some("get") | None => {
            let (out, code) = render_get(&view, filter.as_ref(), None);
            print!("{out}");
            if code == 2 {
                eprintln!("✋ ConstraintError: no window holds it. run: rhx git.crew.space get");
            }
            code
        }
        Some("set") => {
            let Some(ws_ask) = arg(args, "--workspace") else {
                eprintln!("✋ ConstraintError: usage: rhx git.crew.space set --match <text> --workspace <name|last>");
                return 2;
            };
            let Some(f) = filter else {
                eprintln!("✋ ConstraintError: a capture plans a MOVE, so it needs --match, --app-id, or --tree");
                return 2;
            };
            let hits: Vec<&WinRow> = view.wins.iter().filter(|w| f.holds(w)).collect();
            if hits.is_empty() {
                eprintln!("✋ ConstraintError: no window holds '{}'", f.label());
                return 2;
            }
            let target = if ws_ask == "last" {
                match bottom_target(&view, &|w| f.holds(w)) {
                    Some(t) => t,
                    None => {
                        eprintln!("✋ ConstraintError: the capture holds no workspace");
                        return 2;
                    }
                }
            } else {
                ws_ask.clone()
            };
            println!("🪐 git.crew.space set {} --workspace {ws_ask}", f.label());
            if ws_ask == "last" {
                let past = last_occupied_index(&view, &|w| f.holds(w))
                    .map(|i| view.workspaces[i].name.clone())
                    .unwrap_or_else(|| "none".into());
                println!("   ├─ resolved: workspace {target} (the first past the last one another window holds, {past})");
            }
            for w in &hits {
                println!("   ├─ would move: {} (ws {} → {target})", w.title, ws_label(w));
            }
            println!("   └─ plan only: a captured view moves naught");
            0
        }
        Some(other) => {
            eprintln!("✋ ConstraintError: unknown command '{other}'. use: get | set");
            2
        }
    }
}

fn cmd_list(app: &App, filter: Option<&Filter>) -> i32 {
    let debug_line = if is_debug() {
        let info_v = app.cosmic_info.as_ref().map(|i| i.version()).unwrap_or(0);
        let with_handle = app.wins.iter().filter(|w| w.cosmic.is_some()).count();
        Some(format!("   ├─ debug: cosmic info v{} · {}/{} windows hold a cosmic handle", info_v, with_handle, app.wins.len()))
    } else {
        None
    };
    let (out, code) = render_get(&view_of(app), filter, debug_line);
    print!("{out}");
    if code == 2 {
        eprintln!("✋ ConstraintError: no window holds it. run: rhx git.crew.space get");
    }
    code
}

fn arg(args: &[String], flag: &str) -> Option<String> {
    args.iter().position(|a| a == flag).and_then(|i| args.get(i + 1)).cloned()
}

/// make a workspace the active one, so the next window opened lands on it.
/// this is the placement path that works on cosmic-comp today: measured
/// 2026-10-11, a forced move_to_ext_workspace was silently ignored (cap 8 is
/// not advertised), while a new window always opens on the active workspace.
fn cmd_activate(app: &mut App, ws_name: &str, conn: &Connection, queue: &mut EventQueue<App>) -> i32 {
    use ext_workspace_handle_v1::State;
    let Some(target) = app.ws.workspaces().find(|w| w.name == ws_name).cloned() else {
        eprintln!("✋ ConstraintError: no workspace named '{}'. run: rhx git.crew.space get", ws_name);
        return 2;
    };
    let Ok(manager) = app.ws.workspace_manager().get() else {
        eprintln!("💥 MalfunctionError: no ext_workspace_manager bound");
        return 1;
    };
    target.handle.activate();
    manager.commit();
    let _ = conn.flush();
    for _ in 0..10 {
        std::thread::sleep(std::time::Duration::from_millis(50));
        if queue.roundtrip(app).is_err() { break; }
    }
    // verify by re-read; a sent request proves naught
    let active = app
        .ws
        .workspaces()
        .find(|w| w.name == ws_name)
        .map(|w| w.state.contains(State::Active))
        .unwrap_or(false);
    println!("🪐 git.crew.space set --workspace {}", ws_name);
    println!("   └─ {} workspace {} {}", if active { "✅" } else { "💥" }, ws_name, if active { "is active" } else { "did not become active" });
    if active { 0 } else { 1 }
}

fn cmd_move(app: &mut App, args: &[String], conn: &Connection, queue: &mut EventQueue<App>) -> i32 {
    // --crew: pick that crew's workspace and activate it
    if let Some(crew) = arg(args, "--crew") {
        return cmd_place(app, &crew, args, conn, queue);
    }
    let filter = filter_of(args);
    // `--workspace last` resolves to the first workspace past the last one that
    // another window holds — fresh from this read, so no count can drift
    let ws_ask = arg(args, "--workspace");
    let ws_resolved = match ws_ask.as_deref() {
        Some("last") => {
            let view = view_of(app);
            let skip = |w: &WinRow| filter.as_ref().map(|f| f.holds(w)).unwrap_or(false);
            match bottom_target(&view, &skip) {
                Some(t) => Some(t),
                None => {
                    eprintln!("✋ ConstraintError: the compositor reports no workspace");
                    return 2;
                }
            }
        }
        other => other.map(String::from),
    };
    // no --match: activate the workspace rather than move a window onto it
    let Some(filter) = filter else {
        let Some(ws_name) = ws_resolved else {
            eprintln!("✋ ConstraintError: usage: rhx git.crew.space set --workspace <name|last> [--match <text> [--force]]");
            return 2;
        };
        return cmd_activate(app, &ws_name, conn, queue);
    };
    let Some(ws_name) = ws_resolved else {
        eprintln!("✋ ConstraintError: usage: rhx git.crew.space set --match <text> --workspace <name|last> [--force]");
        return 2;
    };
    let needle = filter.label();
    // --force sends the request even where the compositor does not advertise it.
    // the protocol says an unsupported request is ignored, so the re-read below
    // is what tells a real move from a silent no-op.
    let force = args.iter().any(|a| a == "--force");
    if !force && !app.caps.contains(&CAP_MOVE_TO_EXT_WORKSPACE) {
        eprintln!("✋ ConstraintError: compositor does not advertise move_to_ext_workspace (caps {:?}). retry with --force to test it anyway", app.caps);
        return 2;
    }
    let Some(target) = app.ws.workspaces().find(|w| w.name == ws_name).cloned() else {
        eprintln!("✋ ConstraintError: no workspace named '{}'. run: rhx git.crew.space get", ws_name);
        return 2;
    };
    let Some(output) = app
        .ws
        .workspace_groups()
        .find(|g| g.workspaces.contains(&target.handle))
        .and_then(|g| g.outputs.first().cloned())
    else {
        eprintln!("💥 MalfunctionError: workspace '{}' has no output", ws_name);
        return 1;
    };
    let hits: Vec<Win> = live_wins(app)
        .into_iter()
        .filter(|w| filter.holds(&WinRow { ws: Vec::new(), app_id: w.app_id.clone(), title: w.title.clone() }))
        .collect();
    if hits.is_empty() {
        eprintln!("✋ ConstraintError: no window holds '{}'", needle);
        return 2;
    }
    {
        let mgr = &app.mgr.as_ref().expect("a manager is bound").manager;
        for w in &hits {
            if let Some(ct) = &w.cosmic {
                mgr.move_to_ext_workspace(ct, &target.handle, &output);
            }
        }
    }
    let _ = conn.flush();
    // wall-clock waits, as in main: the workspace change lands on a refresh tick
    for _ in 0..10 {
        std::thread::sleep(std::time::Duration::from_millis(50));
        if queue.roundtrip(app).is_err() { break; }
    }
    // verify by re-read; a sent request proves naught about where the window sits
    let mut moved = 0;
    let asked = match ws_ask.as_deref() {
        Some("last") => format!("last (resolved: {ws_name})"),
        _ => ws_name.clone(),
    };
    println!("🪐 git.crew.space set {} --workspace {}{}", needle, asked, if force { " --force" } else { "" });
    // ⚠️ by HANDLE, never by the asked name: a move that empties the source
    //    workspace makes COSMIC drop it and renumber, so the target's name
    //    shifts between the ask and the re-read (verdict_landed)
    for h in &hits {
        let after = app.wins.iter().find(|w| w.ext == h.ext);
        let now = after.map(|w| workspaces_of(app, w)).unwrap_or_else(|| "closed".into());
        let ok = after.map(|w| verdict_landed(&seen_of(app, w), &target.handle)).unwrap_or(false);
        if ok { moved += 1; }
        println!("   ├─ {} {} → ws {}", if ok { "✅" } else { "💥" }, h.title, now);
    }
    let target_now = name_now(app, &target);
    if target_now == ws_name {
        println!("   └─ {}/{} on workspace {}", moved, hits.len(), ws_name);
    } else {
        println!("   └─ {}/{} on workspace {} (asked as {}; COSMIC renumbered it)", moved, hits.len(), target_now, ws_name);
    }
    if moved == hits.len() { 0 } else { 1 }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let _ = DEBUG.set(args.iter().any(|a| a == "--debug"));
    // --from-capture: read a captured view instead of the compositor. the clamp
    // seam — get renders it, set only plans, and no window can move
    if let Some(path) = arg(&args, "--from-capture") {
        std::process::exit(run_capture(&args, &path));
    }
    let conn = match Connection::connect_to_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("💥 MalfunctionError: no wayland connection: {e}");
            std::process::exit(1);
        }
    };
    let (globals, mut queue) = registry_queue_init(&conn).expect("registry init");
    let qh = queue.handle();
    let registry_state = RegistryState::new(&globals);

    // ORDER: workspaces first, windows second. the compositor names a window's
    //    workspace by an ext_workspace handle, so that handle must already be
    //    held when the window's `ext_workspace_enter` arrives.
    //    ⚠️ order alone was not the cure: measured 2026-10-11, every window still
    //    read `ws -` until the wall-clock wait below was added.
    let mut app = App {
        output_state: OutputState::new(&globals, &qh),
        ws: WorkspaceState::new(&registry_state, &qh),
        mgr: ToplevelManagerState::try_new(&registry_state, &qh),
        registry_state,
        caps: Vec::new(),
        cosmic_info: None,
        wins: Vec::new(),
    };
    for _ in 0..3 {
        queue.roundtrip(&mut app).expect("roundtrip");
    }

    // then the cosmic half, so every ext toplevel can ask for its cosmic twin
    app.cosmic_info = globals.bind(&qh, 2..=3, ()).ok();
    let list: Result<ext_list::ExtForeignToplevelListV1, _> = globals.bind(&qh, 1..=1, ());
    if list.is_err() {
        eprintln!("✋ ConstraintError: compositor offers no ext_foreign_toplevel_list — not COSMIC?");
        std::process::exit(2);
    }
    for _ in 0..6 {
        queue.roundtrip(&mut app).expect("roundtrip");
    }
    // 🔴 give the compositor wall-clock time too. cosmic-comp answers
    //    `get_cosmic_toplevel` on its next refresh tick, not inline, so a
    //    back-to-back roundtrip chain returns before a single window event lands.
    //    measured 2026-10-11: zero events with roundtrips alone; state, output and
    //    ext_workspace_enter for every window once 50ms sleeps sat between them
    for _ in 0..10 {
        std::thread::sleep(std::time::Duration::from_millis(50));
        queue.roundtrip(&mut app).expect("roundtrip");
    }
    let code = match args.get(1).map(String::as_str) {
        // get / set, never list / move: rhx claims `list` as its own command,
        // so `rhx git.crew.space list` would run rhx's list rather than this
        // every get also records where each crew sits, so a crash loses at
        // most the moves made since the last get
        Some("get") | None => {
            // --order: print the recorded crews, one tree per line, in the order
            // of the workspace each last sat on. a restore walks this list so
            // the crews come back in the same left-to-right order. it reads the
            // record BEFORE this run's record pass, since after a crash no crew
            // window is live and a fresh pass would record naught anyway.
            if args.iter().any(|a| a == "--order") {
                let mut rows: Vec<(u64, String)> = store_read()
                    .into_iter()
                    .map(|(tree, key)| {
                        let n = key.trim_start_matches("name:").parse::<u64>().unwrap_or(u64::MAX);
                        (n, tree)
                    })
                    .collect();
                rows.sort();
                for (_, tree) in rows { println!("{tree}"); }
                std::process::exit(0);
            }
            // --capture: print the live view as capture lines, and write naught.
            // it sits BEFORE the record pass, so a caller that polls (a terminal
            // snapshot, every few minutes) reads the compositor and mutates no file
            if args.iter().any(|a| a == "--capture") {
                print!("{}", render_capture(&view_of(&app)));
                std::process::exit(0);
            }
            let seen = record_crews(&app);
            // --active: print only the active workspace name, so a caller can
            // return the human to it after a crew window is placed elsewhere
            if args.iter().any(|a| a == "--active") {
                use ext_workspace_handle_v1::State;
                let Some(name) = app.ws.workspaces().find(|w| w.state.contains(State::Active)).map(|w| w.name.clone()) else {
                    eprintln!("💥 MalfunctionError: no workspace reads active");
                    std::process::exit(1);
                };
                println!("{name}");
                std::process::exit(0);
            }
            if args.iter().any(|a| a == "--quiet") {
                0
            } else {
                let code = cmd_list(&app, filter_of(&args).as_ref());
                println!("   🗂️  recorded {} crew window(s) → {}", seen, store_path().display());
                code
            }
        }
        Some("set") => cmd_move(&mut app, &args, &conn, &mut queue),
        Some(other) => {
            eprintln!("✋ ConstraintError: unknown command '{other}'. use: get | set");
            2
        }
    };
    std::process::exit(code);
}

#[cfg(test)]
mod tests {
    use super::*;

    // a capture written by `get --capture` reads back as the same view, and a
    // title that carries a tab or a newline cannot split its row
    #[test]
    fn a_capture_round_trips_and_strips_control_bytes() {
        let view = View {
            can_move: true,
            mgr_version: 4,
            caps: Vec::new(),
            workspaces: vec![WsRow { name: "1".into(), coords: "[0]".into(), active: true }],
            wins: vec![
                WinRow { ws: vec!["1".into()], app_id: "kitty".into(), title: "tab\there\nnext".into() },
                WinRow { ws: Vec::new(), app_id: "firefox".into(), title: "mail".into() },
            ],
        };
        let body = render_capture(&view);
        let back = view_from_capture(&body).expect("the capture parses");
        assert!(back.can_move);
        assert_eq!(back.mgr_version, 4);
        assert_eq!(back.workspaces.len(), 1);
        assert!(back.workspaces[0].active);
        assert_eq!(back.wins.len(), 2);
        assert_eq!(back.wins[0].title, "tabherenext");
        assert_eq!(back.wins[0].ws, vec!["1".to_string()]);
        assert!(back.wins[1].ws.is_empty());
    }

    fn ws(handle: u32, name: &str) -> WsSeen<u32> {
        WsSeen { handle, name: name.to_string() }
    }

    // measured 2026-10-19 (10kpm subdirector): `set` moved a window onto
    // workspace 5, the source workspace emptied, COSMIC dropped it and
    // renumbered, so the target now reads `4`. the move landed; the verdict
    // read the stale name and printed 0/1.
    #[test]
    fn a_move_that_lands_through_a_renumber_reads_landed() {
        let after = vec![ws(5, "4")];
        assert!(verdict_landed(&after, &5u32));
    }

    // counter: after the renumber the asked NAME may belong to a neighbor.
    // a window that sits there did NOT land where it was asked.
    #[test]
    fn a_window_on_the_neighbor_that_inherited_the_name_reads_not_landed() {
        let after = vec![ws(6, "5")];
        assert!(!verdict_landed(&after, &5u32));
    }

    // the plain case, no renumber
    #[test]
    fn a_move_with_no_renumber_reads_landed() {
        let after = vec![ws(5, "5")];
        assert!(verdict_landed(&after, &5u32));
    }

    fn capture() -> View {
        view_from_capture(
            "move\t0\t4\nws\t1\t[0]\t1\nws\t2\t[1]\t0\nws\t3\t[2]\t0\nws\t4\t[3]\t0\n\
             win\t1\tfirefox\tmail\nwin\t2\tcrew.nheuron_direction_x\tcrew x\nwin\t3\tcrew.nheuron_direction_y\tcrew y\n",
        )
        .expect("capture parses")
    }

    // the bottom is the first workspace past the last one ANOTHER window holds
    #[test]
    fn last_resolves_past_the_last_occupied_workspace() {
        let v = capture();
        assert_eq!(bottom_target(&v, &|w| w.app_id == "crew.nheuron_direction_x").as_deref(), Some("4"));
    }

    // a window already alone at the bottom stays where it is
    #[test]
    fn last_for_the_bottom_window_is_its_own_workspace() {
        let v = capture();
        assert_eq!(bottom_target(&v, &|w| w.app_id == "crew.nheuron_direction_y").as_deref(), Some("3"));
    }

    #[test]
    fn app_id_filter_is_exact_where_match_is_a_part() {
        let v = capture();
        let part = Filter::Part("crew.".into());
        let exact = Filter::AppId("crew.nheuron_direction_x".into());
        assert_eq!(v.wins.iter().filter(|w| part.holds(w)).count(), 2);
        assert_eq!(v.wins.iter().filter(|w| exact.holds(w)).count(), 1);
    }

    #[test]
    fn a_filtered_get_names_the_last_occupied_and_only_its_hits() {
        let (out, code) = render_get(&capture(), Some(&Filter::Part("crew x".into())), None);
        assert_eq!(code, 0);
        assert!(out.contains("last occupied: 3"));
        assert!(out.contains("windows: 1 of 3 hold it"));
        assert!(!out.contains("workspaces"));
        assert!(!out.contains("firefox"));
    }

    #[test]
    fn a_window_that_never_moved_reads_not_landed() {
        let after = vec![ws(2, "2")];
        assert!(!verdict_landed(&after, &5u32));
    }
}