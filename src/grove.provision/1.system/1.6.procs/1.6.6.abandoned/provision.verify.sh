#!/usr/bin/env bash
######################################################################
# .what = prove both units match THIS checkout, and the timer is enabled and armed
#
# .why bytes, not presence; enabled AND active — see `1.6.4.keyrackd`'s verify
######################################################################

grove_provision_1_6_6_abandoned_provision_verify() {
  local unit_dir service_name timer_name timer_src claims=0
  unit_dir="$(grove_provision_1_6_6_abandoned_unit_dir)"
  service_name="$(grove_provision_1_6_6_abandoned_service_name)"
  timer_name="$(grove_provision_1_6_6_abandoned_timer_name)"
  timer_src="$GROVE_SRC/machine/$timer_name"
  local fix="fix: rhx grove.provision --what 1.6.6.abandoned --mode apply"

  if grove_provision_1_6_6_abandoned_service_text | cmp -s - "$unit_dir/$service_name"; then
    echo "   • $service_name matches this checkout ✔"
  else
    echo "   ✋ $unit_dir/$service_name does NOT match this checkout — an old path or age gate" >&2
    echo "      $fix" >&2
    claims=$((claims + 1))
  fi

  if cmp -s "$timer_src" "$unit_dir/$timer_name"; then
    echo "   • $timer_name matches this checkout ✔"
  else
    echo "   ✋ $unit_dir/$timer_name does NOT match $timer_src" >&2
    echo "      $fix" >&2
    claims=$((claims + 1))
  fi

  if systemctl --user is-enabled "$timer_name" >/dev/null 2>&1 \
    && systemctl --user is-active "$timer_name" >/dev/null 2>&1; then
    echo "   • $timer_name is enabled and armed ✔"
  else
    echo "   ✋ $timer_name is not enabled and armed — abandoned processes accrue unwatched" >&2
    echo "      $fix" >&2
    claims=$((claims + 1))
  fi

  [[ "$claims" -eq 0 ]]
}
