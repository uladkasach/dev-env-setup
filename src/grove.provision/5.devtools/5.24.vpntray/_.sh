#!/usr/bin/env bash
######################################################################
# .what = a panel shield — green while traffic leaves through an exit node, a
#         grey outline while it goes direct, amber while paused for a captive
#         portal — started at every login on a laptop
#
# .why
#   - the exit node is off by default and switched on for a network the human
#     does not trust (`plan.exit-node`). a switch with no visible state is one
#     the human forgets — the shield answers "am i on the vpn?" at a glance
#   - tailscale's own tray (`tailscale systray`) shows the tailnet link, and
#     names the exit node only inside its menu. it was retired for this
#
# .why our own rust binary
#   - a tray icon needs a StatusNotifierItem on the session bus; a shell file
#     cannot host one, and python's tray libraries pull in a runtime this repo
#     avoids (`rule.avoid.python-runtimes`). `5.2.rust` already installs cargo
#   - the source sits in `vpntray/`, beside the phases that build it
#
# .why an xdg autostart entry, and not a systemd user unit
#   - a tray app must start INSIDE the graphical session, with its display and
#     its session bus. both cosmic and gnome run `~/.config/autostart` at login;
#     a user unit needs `graphical-session.target`, which a session may not raise
#
# .why `local@unix` alone
#   - it is the one tier with a human at a screen. a grove has no panel, and its
#     tailscale is its provisioner's (`define.invariant.grove-tailscale-has-one-owner`)
#
# usage:
#   rhx grove.provision --what 5.24.vpntray --mode apply
######################################################################

grove_provision_5_24_vpntray_dir() { printf '%s' "$GROVE_SRC/grove.provision/5.devtools/5.24.vpntray"; }
grove_provision_5_24_vpntray_bin_at() { printf '%s/.local/bin/grove-vpntray' "$HOME"; }
grove_provision_5_24_vpntray_entry_at() { printf '%s/.config/autostart/grove-vpntray.desktop' "$HOME"; }
grove_provision_5_24_vpntray_stamp_at() { printf '%s/.local/share/grove/vpntray.src.sha256' "$HOME"; }

# the tray tailscale ships, retired by this bundle
grove_provision_5_24_vpntray_legacy_entry_at() { printf '%s/.config/autostart/tailscale-systray.desktop' "$HOME"; }

# .what = does this tier get the shield? — and if not, say why
grove_provision_5_24_vpntray_applies() {
  [[ "${GROVE_ENV_SERVER:-}" == local@unix ]] && return 0
  echo "   🌙 declined — tier '${GROVE_ENV_SERVER:-<unset>}' has no human at a panel"
  return 1
}

# .what = one hash over the crate's source — the binary is current iff its
#         stamp holds this hash
grove_provision_5_24_vpntray_src_hash() {
  local crate
  crate="$(grove_provision_5_24_vpntray_dir)/vpntray"
  cat "$crate/Cargo.toml" "$crate/Cargo.lock" "$crate/src/main.rs" 2>/dev/null | sha256sum | cut -d' ' -f1
}

# .what = the pid of this user's shield, or naught
grove_provision_5_24_vpntray_pid() {
  pgrep -u "$(id -u)" -x grove-vpntray 2>/dev/null | head -n 1
}

# .what = the pid of this user's retired tailscale tray, or naught
grove_provision_5_24_vpntray_legacy_pid() {
  pgrep -u "$(id -u)" -f '^(/usr/bin/)?tailscale systray' 2>/dev/null | head -n 1
}

grove_provision_5_24_vpntray() {
  bundle.upgrade 5.24.vpntray.configure.upsert
  bundle.upgrade 5.24.vpntray.configure.verify
}
