#!/usr/bin/env bash
######################################################################
# .what = prove the monitor's files match this checkout AND that its timer is
#         actually ACTIVE
#
# ⚠️ .why the timer's state is its own claim
#         the three files can be byte-perfect while the timer is disabled,
#         masked, or failed. in that state every file check passes and NO check
#         ever runs — the box is unmonitored and reports as configured.
#
#         `systemctl --user is-active` is the only reader of that fact. this is
#         the same distinction `5.1.node.configure.verify` draws between "the
#         bytes arrived" and "the capacity exists".
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_1_6_2_monitor_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no notification bus on $GROVE_ENV_SERVER, so no"
    echo "      monitor is expected here"
    return 0
  fi

  local failed=0
  local bin_dir="$HOME/.local/bin"
  local unit_dir="$HOME/.config/systemd/user"

  ####################################################################
  # 1. the three files match this checkout
  ####################################################################
  local pair
  for pair in \
    "machine_resource_procs_monitor:$bin_dir/machine_resource_procs_monitor" \
    "runaway_monitor.service:$unit_dir/runaway_monitor.service" \
    "runaway_monitor.timer:$unit_dir/runaway_monitor.timer"
  do
    local name="${pair%%:*}"
    local dst="${pair#*:}"
    local src="$GROVE_SRC/machine/$name"

    if [[ ! -f "$dst" ]]; then
      echo "   ✋ $name is absent from $dst" >&2
      echo "      fix: rhx grove.provision --what 1.6.2.monitor --mode apply" >&2
      failed=1
    elif [[ ! -f "$src" ]]; then
      echo "   🌙 $name is installed, but this checkout holds no $src"
    elif diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "   • $name matches this checkout ✔"
    else
      echo "   ✋ the installed $name DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      fix: rhx grove.provision --what 1.6.2.monitor --mode apply" >&2
      failed=1
    fi
  done

  ####################################################################
  # 2. THE claim — the timer is live NOW and survives a reboot
  #
  # see the header for why byte-perfect files leave this unproven
  #
  # ⚠️ .why BOTH `is-active` and `is-enabled`
  #      they answer different questions and neither implies the other:
  #        is-active  → is it live in THIS boot
  #        is-enabled → will it come back after a REBOOT
  #      a `systemctl --user start` with no `enable` is active and disabled: it
  #      passes an is-active check today and is gone tomorrow, and the box is
  #      then unmonitored with every file still byte-perfect. the enable-state is
  #      the load-bear half for a unit meant to outlive one session
  ####################################################################
  local state_active state_enabled
  state_active="$(systemctl --user is-active runaway_monitor.timer 2>/dev/null)"
  state_enabled="$(systemctl --user is-enabled runaway_monitor.timer 2>/dev/null)"

  if [[ "$state_active" == "active" ]]; then
    local next
    next="$(systemctl --user list-timers runaway_monitor.timer --no-pager 2>/dev/null | head -2 | tail -1)"
    echo "   • runaway_monitor.timer is active ✔"
    [[ -n "$next" ]] && echo "     next: $next"
  else
    echo "   ✋ runaway_monitor.timer is '${state_active:-absent}', not active" >&2
    echo "      ⇒ every file above can be byte-perfect and NO check runs, so" >&2
    echo "        the box is unmonitored while it reports as configured" >&2
    echo "      read why: systemctl --user status runaway_monitor.timer" >&2
    echo "      fix: rhx grove.provision --what 1.6.2.monitor --mode apply" >&2
    failed=1
  fi

  if [[ "$state_enabled" == "enabled" ]]; then
    echo "   • runaway_monitor.timer is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ runaway_monitor.timer is '${state_enabled:-absent}', not enabled" >&2
    echo "      ⇒ it may be active THIS boot and gone the next, so the box goes" >&2
    echo "        unmonitored while the check above still passes" >&2
    echo "      fix: rhx grove.provision --what 1.6.2.monitor --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 3. the two sinks the monitor reports THROUGH
  #
  # ⚠️ .why these are asserted, and why their absence was invisible
  #      the old installer aborted the whole run when `notify-send` or `logger`
  #      was absent. the migration carried over neither check, and no bundle on
  #      either side installs `libnotify-bin` — so the timer can be perfectly
  #      active, on a box where every alert it raises reaches no one.
  #
  #      that is worse than a monitor that fails: a failed timer is loud, while
  #      this one reports ✔ at every layer and the box is silently unwatched.
  #      the bundle's own `_.sh` argues that a check nobody reads is no check;
  #      the same holds one step further out, for an alert with no sink.
  #
  # .why notify-send is a ✋ and not a 🌙 here
  #      this bundle already declines wholesale off a local box, so by the time
  #      this line runs a human and a screen are both confirmed. a desktop that
  #      cannot raise a desktop notification is a real defect, not an
  #      inapplicable claim
  ####################################################################
  local sink sink_absent=()
  for sink in notify-send logger; do
    command -v "$sink" >/dev/null 2>&1 || sink_absent+=("$sink")
  done

  if [[ "${#sink_absent[@]}" -eq 0 ]]; then
    echo "   • both alert sinks are present ✔ (notify-send, logger)"
  else
    echo "   ✋ the monitor has no way to report: ${sink_absent[*]} absent" >&2
    echo "      ⇒ the timer still fires and the checks still run — every alert" >&2
    echo "        they raise is simply discarded, while this bundle reports ✔" >&2
    echo "      ⇒ notify-send is the desktop toast; logger is the journal trail," >&2
    echo "        which is the only record that survives a session" >&2
    echo "      fix: rhx grove.provision --what 1.6.2.monitor --mode apply" >&2
    failed=1
  fi

  return $failed
}
