#!/usr/bin/env bash
######################################################################
# .what = prove the four installed files match this checkout, that the timer is
#         both ENABLED and ACTIVE, and that the snapper is executable
#
# ⚠️ .why the timer needs BOTH `is-enabled` and `is-active`
#         they answer different questions and neither implies the other:
#           is-active  → is it live in THIS boot
#           is-enabled → will it come back after a REBOOT
#         a `systemctl --user start` with no `enable` is active and disabled: it
#         passes an is-active check today and is gone tomorrow. the inverse —
#         enabled but inactive — is a unit that failed to start this boot. a
#         guard whose whole job is to fire on an unattended battery die must
#         survive a reboot, so the enable-state is the load-bear half.
#
# ⚠️ .why the SNAPPER's executable bit is asserted
#         the guard is invoked by systemd at 5% battery, it redirects its own
#         errors to /dev/null so a dead laptop is not made worse by a stack
#         trace, and it `touch`es its marker either way. so an unexecutable
#         snapper produces a marker, a journal line that reads "snapped", and no
#         snap file — a failure that LOOKS like a success in the one log a human
#         would read afterward (`rule.forbid.failhide`).
#
#         the byte-diff in claim 1 cannot see a mode bit, so this is its pair.
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_4_3_4_snapshot_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no kitty windows on $GROVE_ENV_SERVER, so no snap"
    echo "      guard is expected here"
    return 0
  fi

  local failed=0
  local bin_dir="$HOME/.local/bin"
  local unit_dir="$HOME/.config/systemd/user"

  ####################################################################
  # 1. the four files match this checkout
  ####################################################################
  local pair
  for pair in \
    "kitty.snapshot.terminals.sh:$bin_dir/kitty.snap" \
    "kitty_snap_lowbatt:$bin_dir/kitty_snap_lowbatt" \
    "kitty_snap_lowbatt.service:$unit_dir/kitty_snap_lowbatt.service" \
    "kitty_snap_lowbatt.timer:$unit_dir/kitty_snap_lowbatt.timer"
  do
    local name="${pair%%:*}"
    local dst="${pair#*:}"
    local src="$GROVE_SRC/machine/$name"

    if [[ ! -f "$dst" ]]; then
      echo "   ✋ $name is absent from $dst" >&2
      echo "      fix: rhx grove.provision --what 4.3.4.snapshot --mode apply" >&2
      failed=1
    elif [[ ! -f "$src" ]]; then
      echo "   🌙 $name is installed, but this checkout holds no $src"
    elif diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "   • $name matches this checkout ✔"
    else
      echo "   ✋ the installed $name DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      fix: rhx grove.provision --what 4.3.4.snapshot --mode apply" >&2
      failed=1
    fi
  done

  ####################################################################
  # 2. THE claim — the timer is live NOW and survives a reboot
  #
  # see the header for why these are two claims, not one
  ####################################################################
  local state_active state_enabled
  state_active="$(systemctl --user is-active kitty_snap_lowbatt.timer 2>/dev/null)"
  state_enabled="$(systemctl --user is-enabled kitty_snap_lowbatt.timer 2>/dev/null)"

  if [[ "$state_active" == "active" ]]; then
    local next
    next="$(systemctl --user list-timers kitty_snap_lowbatt.timer --no-pager 2>/dev/null | head -2 | tail -1)"
    echo "   • kitty_snap_lowbatt.timer is active ✔"
    [[ -n "$next" ]] && echo "     next: $next"
  else
    echo "   ✋ kitty_snap_lowbatt.timer is '${state_active:-absent}', not active" >&2
    echo "      ⇒ every file above can be byte-perfect and NO snap fires, so the" >&2
    echo "        session map is lost the one time it costs most to lose" >&2
    echo "      read why: systemctl --user status kitty_snap_lowbatt.timer" >&2
    echo "      fix: rhx grove.provision --what 4.3.4.snapshot --mode apply" >&2
    failed=1
  fi

  if [[ "$state_enabled" == "enabled" ]]; then
    echo "   • kitty_snap_lowbatt.timer is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ kitty_snap_lowbatt.timer is '${state_enabled:-absent}', not enabled" >&2
    echo "      ⇒ it may be active THIS boot and gone the next, so the guard" >&2
    echo "        silently stops guarding the box while the check above passes" >&2
    echo "      fix: rhx grove.provision --what 4.3.4.snapshot --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 3. the snapper's mode bit — see the header for why a byte-diff misses it
  ####################################################################
  if [[ -x "$bin_dir/kitty.snap" ]]; then
    echo "   • kitty.snap is executable ✔"
  else
    echo "   ✋ $bin_dir/kitty.snap is not executable" >&2
    echo "      ⇒ the guard discards its own errors, so it still writes a marker" >&2
    echo "        and a journal line that reads 'snapped' — with no snap file" >&2
    echo "      fix: rhx grove.provision --what 4.3.4.snapshot --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 4. `logger`, the guard's only durable trail
  #
  # .why it is asserted and not installed
  #      it ships in `bsdutils`, essential on every debian box, so an install
  #      line would be a claim that can never be false. the check still runs,
  #      because "can never be false" is a belief about the platform and one
  #      `command -v` is what turns it into an observation
  ####################################################################
  if command -v logger >/dev/null 2>&1; then
    echo "   • logger is present ✔"
  else
    echo "   ✋ logger is absent" >&2
    echo "      ⇒ the guard's journal line is the only record that a snap was" >&2
    echo "        taken; without it a snap and a silent no-op look the same" >&2
    failed=1
  fi

  ####################################################################
  # 5. whether a snap has EVER been taken — reported, never failed
  #
  # a box that has not dropped below 10% since install owes no snap, so an
  # empty dir is the correct state on a healthy laptop. it is worth a line
  # anyway: an empty dir on a box that HAS been low is the tell
  ####################################################################
  local snaps="$HOME/.kitty/snaps"
  local count=0
  [[ -d "$snaps" ]] && count="$(find "$snaps" -maxdepth 1 -name '*.json' -type f 2>/dev/null | wc -l)"
  if [[ "$count" -gt 0 ]]; then
    echo "   • $count snap(s) on record at $snaps"
  else
    echo "   🌙 no snap on record yet at $snaps — correct if this box has not"
    echo "      dropped below 10% since install. take one by hand with: kitty.snap"
  fi

  return $failed
}
