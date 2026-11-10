#!/usr/bin/env bash
######################################################################
# .what = build the shield, declare it to start at every login, retire the
#         tailscale tray it replaces, and start the shield now where a panel is
#
# .why the build is keyed on a source hash
#   - cargo rebuilds only what changed, but a cold check still costs seconds;
#     the stamp makes a second apply a pure read
#   - the first build writes `Cargo.lock` beside the source; it is tracked, and
#     every later build runs `--locked`, so a box builds the crates the repo pinned
#
# .why the shield is started now, too
#   - the entry takes at the next login; a human who just applied wants the
#     shield today. it starts detached, so the apply never waits on it
#   - it starts only where this shell holds a display AND a session bus: from a
#     duct or a tty there is no panel to draw into
#
# guarantee:
#   - idempotent: each write lands only where it differs
#   - no root: every write lands in $HOME
######################################################################

grove_provision_5_24_vpntray_configure_upsert() {
  grove_provision_5_24_vpntray_applies || return 0

  local dir crate bin entry stamp
  dir="$(grove_provision_5_24_vpntray_dir)"
  crate="$dir/vpntray"
  bin="$(grove_provision_5_24_vpntray_bin_at)"
  entry="$(grove_provision_5_24_vpntray_entry_at)"
  stamp="$(grove_provision_5_24_vpntray_stamp_at)"

  # 0. the shield reads tailscale; its build needs cargo
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "   ✋ ConstraintError: tailscale is absent — the shield has no route to show" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" >&2
    return 1
  fi
  local cargo="${CARGO_HOME:-$HOME/.cargo}/bin/cargo"
  [[ -x "$cargo" ]] || cargo="$(command -v cargo 2>/dev/null)"
  if [[ -z "$cargo" ]]; then
    echo "   ✋ ConstraintError: cargo is absent — the shield cannot be built" >&2
    echo "      fix: rhx grove.provision --what 5.2.rust --mode apply" >&2
    return 1
  fi

  # 1. the binary — rebuilt only when the source hash moved
  local rebuilt=false
  if [[ -x "$bin" && "$(cat "$stamp" 2>/dev/null)" == "$(grove_provision_5_24_vpntray_src_hash)" ]]; then
    echo "   • binary current ✔"
  else
    local locked=()
    [[ -f "$crate/Cargo.lock" ]] && locked=(--locked)
    local target="$HOME/.cache/grove/vpntray-target"
    echo "   • build: cargo build --release ${locked[*]}"
    # cargo's own exit is the verdict; its output is captured so a pipe cannot mask it
    local log
    if ! log="$(CARGO_TARGET_DIR="$target" "$cargo" build --release "${locked[@]}" --manifest-path "$crate/Cargo.toml" 2>&1)"; then
      printf '%s\n' "$log" | tail -n 30 | sed 's/^/      /' >&2
      echo "   💥 MalfunctionError: cargo build failed — see its output above" >&2
      return 1
    fi
    if [[ ! -x "$target/release/grove-vpntray" ]]; then
      echo "   💥 MalfunctionError: cargo build produced no binary at $target/release/grove-vpntray" >&2
      return 1
    fi
    mkdir -p "$(dirname "$bin")" "$(dirname "$stamp")" \
      && install -m 0755 "$target/release/grove-vpntray" "$bin" \
      && grove_provision_5_24_vpntray_src_hash > "$stamp" || {
        echo "   💥 MalfunctionError: could not install $bin" >&2
        return 1
      }
    echo "   • binary installed: $bin"
    rebuilt=true
  fi

  # 2. the declaration — started at every login
  if cmp -s "$dir/grove-vpntray.desktop" "$entry"; then
    echo "   • autostart entry current ✔"
  else
    mkdir -p "$(dirname "$entry")" && install -m 0644 "$dir/grove-vpntray.desktop" "$entry" || {
      echo "   💥 MalfunctionError: could not write $entry" >&2
      return 1
    }
    echo "   • autostart entry declared: $entry"
  fi

  # 3. retire tailscale's own tray — its entry, and the process it started
  local legacy legacy_pid
  legacy="$(grove_provision_5_24_vpntray_legacy_entry_at)"
  if [[ -e "$legacy" ]]; then
    rm -f "$legacy" && echo "   • retired: $legacy"
  fi
  legacy_pid="$(grove_provision_5_24_vpntray_legacy_pid)"
  if [[ -n "$legacy_pid" ]]; then
    kill "$legacy_pid" 2>/dev/null && echo "   • retired: tailscale systray (pid $legacy_pid) stopped"
  fi

  # 4. this session — only where a panel can receive it
  local pid
  pid="$(grove_provision_5_24_vpntray_pid)"
  if [[ -n "$pid" && "$rebuilt" == false ]]; then
    echo "   • shield already up ✔"
    return 0
  fi
  if [[ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" || -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    echo "   🌙 no graphical session in this shell — the shield starts at the next login"
    return 0
  fi
  # a rebuilt binary replaces the one up now
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null && sleep 0.5
  setsid -f "$bin" >/dev/null 2>&1 </dev/null
  # past one 3s poll, so a shield cut from the session bus has exited by now
  sleep 5
  if [[ -z "$(grove_provision_5_24_vpntray_pid)" ]]; then
    echo "   💥 MalfunctionError: the shield exited — it could not reach the panel on the session bus" >&2
    echo "      ⇒ a sandboxed shell (an agent's) holds no session bus; run this apply from your own terminal" >&2
    echo "      read why: $bin    # run it in a terminal; it prints its error" >&2
    return 1
  fi
  echo "   • shield started — green while on an exit node, a grey outline while direct, amber while paused for a portal"
}
