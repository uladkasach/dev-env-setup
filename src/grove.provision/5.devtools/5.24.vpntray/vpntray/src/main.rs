//! .what = a panel shield that answers one question: is traffic on the vpn?
//!
//!   - green shield, filled   — an exit node is in use (`via <host>` in the tooltip)
//!   - grey shield, outline   — direct; traffic leaves by the network the laptop is on
//!   - amber shield, filled   — paused for a captive portal, or tailscaled did not answer
//!
//! .why its own icon, drawn here
//!   - tailscale's tray shows connected/disconnected, and names the exit node
//!     only inside its menu — so the one fact the human glances for is hidden
//!   - the shield is drawn as a pixmap, so it reads the same under any theme
//!
//! .why "off" still draws a mark
//!   - an absent icon reads the same as a dead tray. a grey outline says "direct"
//!     and proves the shield itself is alive
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

/// .what = is pixel (x, y) inside a 22px shield? — a flat top, straight sides,
///         and a taper to a point at the bottom
fn is_in_shield(x: i32, y: i32) -> bool {
    let (top, shoulder, tip) = (2, 10, 20);
    if y < top || y > tip {
        return false;
    }
    let half = if y <= shoulder {
        8.0
    } else {
        8.0 * (tip - y) as f32 / (tip - shoulder) as f32
    };
    ((x as f32) - 10.5).abs() <= half
}

/// .what = is pixel (x, y) on the shield's 2px border? — the outline form
fn is_on_shield_edge(x: i32, y: i32) -> bool {
    if !is_in_shield(x, y) {
        return false;
    }
    let near = [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, -1), (-1, 1), (1, 1)];
    near.iter().any(|(dx, dy)| !is_in_shield(x + dx, y + dy))
}

/// .what = the icon for a route, ARGB32 in network byte order — the pixmap
///         format the StatusNotifierItem spec asks for
fn draw_icon(route: &Route) -> ksni::Icon {
    let size: i32 = 22;
    let (rgb, filled): ([u8; 3], bool) = match route {
        Route::Exit(_) => ([0x2e, 0xc2, 0x7e], true),
        Route::Unknown | Route::Paused => ([0xe5, 0xa5, 0x0a], true),
        Route::Direct => ([0x9a, 0x99, 0x96], false),
    };
    let mut data = Vec::with_capacity((size * size * 4) as usize);
    for y in 0..size {
        for x in 0..size {
            let mark = if filled { is_in_shield(x, y) } else { is_on_shield_edge(x, y) };
            if mark {
                data.extend_from_slice(&[0xff, rgb[0], rgb[1], rgb[2]]);
            } else {
                data.extend_from_slice(&[0x00, 0x00, 0x00, 0x00]);
            }
        }
    }
    ksni::Icon { width: size, height: size, data }
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
    fn id(&self) -> String {
        "grove-vpntray".to_string()
    }

    fn title(&self) -> String {
        self.label()
    }

    fn icon_pixmap(&self) -> Vec<ksni::Icon> {
        vec![draw_icon(&self.route)]
    }

    fn tool_tip(&self) -> ksni::ToolTip {
        ksni::ToolTip {
            title: self.label(),
            ..Default::default()
        }
    }

    fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        vec![ksni::menu::StandardItem {
            label: self.label(),
            enabled: false,
            ..Default::default()
        }
        .into()]
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
