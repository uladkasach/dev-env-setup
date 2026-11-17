//! .what = a panel shield that answers one question: is traffic on the vpn?
//!
//!   - `network-vpn`              — an exit node is in use (`via <host>` in the tooltip)
//!   - `network-vpn-disconnected` — direct; traffic leaves by the network the laptop is on
//!   - `network-vpn-acquiring`    — paused for a captive portal; sign-in resumes it
//!   - `network-vpn-error`        — tailscaled did not answer
//!
//! .why the theme's own vpn icons, by name
//!   - tailscale's tray shows connected/disconnected, and names the exit node
//!     only inside its menu — so the one fact the human glances for is hidden
//!   - a named symbolic icon draws in the panel's own style: crisp at any scale,
//!     and it follows light and dark. a hand-drawn 22px pixmap did neither.
//!     the cost is colour — the state reads by shape, not green versus grey
//!
//! .why "off" still draws a mark
//!   - an absent icon reads the same as a dead tray. the disconnected icon says
//!     "direct" and proves the shield itself is alive
//!
//! .why a poll every 3s, and not a stream
//!   - `tailscale status --json` is the stable interface; the change stream lives
//!     under `tailscale debug`, which carries no stability promise. one local
//!     socket read every 3s is cheap, and a switch shows within 3s

use std::{process::Command, thread, time::Duration};

use ksni::blocking::TrayMethods;

#[derive(Clone, PartialEq)]
enum Route {
    Exit(String),
    Direct,
    Paused,
    Unknown,
}

/// the mark `grove-exitnode` leaves while it holds the exit node off for a
/// captive portal (`1.13.exitnode`)
const PORTAL_HOLD_AT: &str = "/run/grove/exitnode.held";

/// .what = read the route from tailscaled — three-valued, so a failed read
///         never reads as "direct"
fn read_route() -> Route {
    let out = match Command::new("tailscale").args(["status", "--json"]).output() {
        Ok(out) if out.status.success() => out.stdout,
        _ => return Route::Unknown,
    };
    let json: serde_json::Value = match serde_json::from_slice(&out) {
        Ok(json) => json,
        Err(_) => return Route::Unknown,
    };
    let peers = match json.get("Peer").and_then(|p| p.as_object()) {
        Some(peers) => peers,
        None => return Route::Direct,
    };
    peers
        .values()
        .find(|peer| peer.get("ExitNode").and_then(|e| e.as_bool()) == Some(true))
        .map(|peer| {
            let host = peer.get("HostName").and_then(|h| h.as_str()).unwrap_or("?");
            Route::Exit(host.to_string())
        })
        .unwrap_or_else(|| {
            if std::path::Path::new(PORTAL_HOLD_AT).exists() {
                Route::Paused
            } else {
                Route::Direct
            }
        })
}

/// .what = the theme icon for a route, by name — the panel draws it in its own
///         style, at its own scale, in light or dark
fn icon_name_for(route: &Route) -> &'static str {
    match route {
        Route::Exit(_) => "network-vpn-symbolic",
        Route::Direct => "network-vpn-disconnected-symbolic",
        Route::Paused => "network-vpn-acquiring-symbolic",
        Route::Unknown => "network-vpn-error-symbolic",
    }
}

struct VpnTray {
    route: Route,
}

impl VpnTray {
    fn label(&self) -> String {
        match &self.route {
            Route::Exit(host) => format!("vpn on — via {host}"),
            Route::Direct => "vpn off — direct".to_string(),
            Route::Paused => "vpn paused — captive portal; it resumes once you sign in".to_string(),
            Route::Unknown => "vpn unknown — tailscaled did not answer".to_string(),
        }
    }
}

impl ksni::Tray for VpnTray {
    // a left click opens the menu. ksni's default sends it to `activate`, which
    // this shield leaves empty — so a click did naught. 📜 measured 2026-11-14
    const MENU_ON_ACTIVATE: bool = true;

    fn id(&self) -> String {
        "grove-vpntray".to_string()
    }

    fn title(&self) -> String {
        self.label()
    }

    fn icon_name(&self) -> String {
        icon_name_for(&self.route).to_string()
    }

    fn tool_tip(&self) -> ksni::ToolTip {
        ksni::ToolTip {
            title: self.label(),
            ..Default::default()
        }
    }

    /// .what = the status, then both choices — on and off — every time; the
    ///         one already in effect is greyed out
    ///
    /// .why a menu, and not a click on the icon itself
    ///   - a click that flips the route is one stray tap from a change of
    ///     network path. a menu row is a choice the human reads first
    fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        let is_on = matches!(self.route, Route::Exit(_));
        let is_off = matches!(self.route, Route::Direct);
        let status = ksni::menu::StandardItem {
            label: self.label(),
            enabled: false,
            ..Default::default()
        };
        let on = ksni::menu::StandardItem {
            label: "vpn on — usa".to_string(),
            enabled: !is_on,
            activate: Box::new(|tray: &mut Self| tray.switch("on")),
            ..Default::default()
        };
        let off = ksni::menu::StandardItem {
            label: "vpn off — direct".to_string(),
            enabled: !is_off,
            activate: Box::new(|tray: &mut Self| tray.switch("off")),
            ..Default::default()
        };
        vec![status.into(), ksni::MenuItem::Separator, on.into(), off.into()]
    }
}

/// the root switch `1.13.exitnode` installs; sudoers lets an admin run its
/// `on` and `off` with no password, so `sudo -n` never prompts
const SWITCH_AT: &str = "/usr/local/sbin/grove-exitnode";

impl VpnTray {
    /// .what = run the switch, then show the route it left — never the route
    ///         it was asked for, so a refused switch reads as refused
    fn switch(&mut self, to: &str) {
        let ran = Command::new("sudo").args(["-n", SWITCH_AT, to]).output();
        if !matches!(&ran, Ok(out) if out.status.success()) {
            let why = match ran {
                Ok(out) => String::from_utf8_lossy(&out.stderr).trim().to_string(),
                Err(err) => err.to_string(),
            };
            eprintln!("💥 MalfunctionError: `sudo -n {SWITCH_AT} {to}` failed — {why}");
            eprintln!("   fix: sudo -v && rhx grove.provision --what 1.13.exitnode --mode apply");
        }
        self.route = read_route();
    }
}

fn main() {
    let mut last = read_route();
    let handle = match (VpnTray { route: last.clone() }).spawn() {
        Ok(handle) => handle,
        Err(err) => {
            eprintln!("💥 MalfunctionError: no StatusNotifierWatcher answered — is a panel tray up? ({err})");
            std::process::exit(1);
        }
    };

    // redraw only on a change, so an idle tray sends the panel no signal
    loop {
        thread::sleep(Duration::from_secs(3));

        // a shield cut from the session bus draws on no panel; exit loud, so the
        // apply's liveness check and the next login see it, never a deaf process
        if handle.is_closed() {
            eprintln!("💥 MalfunctionError: the session bus closed — the shield draws on no panel");
            std::process::exit(1);
        }
        let next = read_route();
        if next == last {
            continue;
        }
        last = next.clone();
        handle.update(move |tray| tray.route = next);
    }
}
