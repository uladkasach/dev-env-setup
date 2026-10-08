#!/usr/bin/env bash
######################################################################
# .what = write the reaper's service + timer into this seat's user unit dir,
#         and enable the timer
#
# .why the skip gate reads CONTENT, never presence
#   - a presence test makes a unit write-once, so a later change to the
#     cadence or the age gate reaches no extant box (`1.6.4.keyrackd`)
#
# guarantee:
#   - idempotent: both units re-declared from one reader on every apply
#   - no sudo: the units are user units, and the processes reaped are this
#     seat's own
######################################################################

grove_provision_1_6_6_abandoned_provision_upsert() {
  local unit_dir service_name timer_name bin timer_src
  unit_dir="$(grove_provision_1_6_6_abandoned_unit_dir)"
  service_name="$(grove_provision_1_6_6_abandoned_service_name)"
  timer_name="$(grove_provision_1_6_6_abandoned_timer_name)"
  bin="$(grove_provision_1_6_6_abandoned_bin)"
  timer_src="$GROVE_SRC/machine/$timer_name"

  # both inputs ride in `src/`, so an absence is this checkout's defect
  if [[ ! -x "$bin" || ! -f "$timer_src" ]]; then
    echo "   ✋ this checkout lacks $bin or $timer_src" >&2
    return 1
  fi

  # what is already true — read before any write
  local converged=1
  cmp -s "$timer_src" "$unit_dir/$timer_name" || converged=0
  grove_provision_1_6_6_abandoned_service_text | cmp -s - "$unit_dir/$service_name" || converged=0
  systemctl --user is-enabled "$timer_name" >/dev/null 2>&1 || converged=0
  systemctl --user is-active  "$timer_name" >/dev/null 2>&1 || converged=0
  if [[ "$converged" -eq 1 ]]; then
    echo "   • both units match this checkout, and the timer is armed ✔"
    return 0
  fi

  mkdir -p "$unit_dir" || return 1
  grove_provision_1_6_6_abandoned_service_text > "$unit_dir/$service_name" || return 1
  cp "$timer_src" "$unit_dir/$timer_name" || return 1
  echo "   • $service_name and $timer_name declared"

  # reload FIRST — a rewrite with no reload leaves the old definition live
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ is the user manager up? sudo -v && rhx grove.provision --what 1.6.5.usermanager --mode apply" >&2
    return 1
  }
  systemctl --user enable --now "$timer_name" || {
    echo "   ✋ could not enable $timer_name — abandoned processes accrue unwatched" >&2
    return 1
  }
  echo "   • $timer_name enabled (hourly; reaps what was abandoned over 24h ago)"
}
