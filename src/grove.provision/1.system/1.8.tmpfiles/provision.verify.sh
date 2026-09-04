#!/usr/bin/env bash
######################################################################
# .what = prove the two units match this checkout AND that the timer is ACTIVE
#
# ⚠️ .why the timer's state is its own claim
#   - both files can be byte-perfect while the timer is disabled, masked, or failed
#   - ⇒ every file check passes and NO cleanup ever runs
#   - /tmp accumulates and the next boot pays the walk
#   - the box reports as configured the whole time
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_1_8_tmpfiles_provision_verify() {
  local failed=0
  local unit_dir="/etc/systemd/system"

  ####################################################################
  # 1. the two units match this checkout
  ####################################################################
  local name
  for name in tmp-cleanup.service tmp-cleanup.timer; do
    local dst="$unit_dir/$name"
    local src="$GROVE_SRC/machine/$name"

    if [[ ! -f "$dst" ]]; then
      echo "   ✋ $name is absent from $dst" >&2
      echo "      fix: rhx grove.provision --what 1.8.tmpfiles --mode apply" >&2
      failed=1
    elif [[ ! -f "$src" ]]; then
      echo "   🌙 $name is installed, but this checkout holds no $src"
    elif diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "   • $name matches this checkout ✔"
    else
      echo "   ✋ the installed $name DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      fix: rhx grove.provision --what 1.8.tmpfiles --mode apply" >&2
      failed=1
    fi
  done

  ####################################################################
  # 2. THE claim — the timer is live NOW and survives a reboot
  #
  # ⚠️ .why BOTH `is-active` and `is-enabled`
  #   - `is-active` asks whether it is live in THIS boot
  #   - `is-enabled` asks whether it comes back after a REBOOT
  #   - neither implies the other, and a `systemctl start` with no `enable` is both
  #   - the cost of an unpruned /tmp is paid AT BOOT, by the systemd-tmpfiles walk
  #   - ⇒ a timer that does not survive a reboot is absent at the moment it exists to help
  ####################################################################
  local state_active state_enabled
  state_active="$(systemctl is-active tmp-cleanup.timer 2>/dev/null)"
  state_enabled="$(systemctl is-enabled tmp-cleanup.timer 2>/dev/null)"

  if [[ "$state_active" == "active" ]]; then
    local next
    next="$(systemctl list-timers tmp-cleanup.timer --no-pager 2>/dev/null | head -2 | tail -1)"
    echo "   • tmp-cleanup.timer is active ✔"
    [[ -n "$next" ]] && echo "     next: $next"
  else
    echo "   ✋ tmp-cleanup.timer is '${state_active:-absent}', not active" >&2
    echo "      ⇒ /tmp accumulates unpruned, so the next boot pays the" >&2
    echo "        systemd-tmpfiles walk and the box looks hung on a black screen" >&2
    echo "      read why: systemctl status tmp-cleanup.timer" >&2
    echo "      fix: rhx grove.provision --what 1.8.tmpfiles --mode apply" >&2
    failed=1
  fi

  if [[ "$state_enabled" == "enabled" ]]; then
    echo "   • tmp-cleanup.timer is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ tmp-cleanup.timer is '${state_enabled:-absent}', not enabled" >&2
    echo "      ⇒ it may be active THIS boot and gone the next — and the boot is" >&2
    echo "        exactly where an unpruned /tmp costs, so the gap is invisible" >&2
    echo "        until the black screen" >&2
    echo "      fix: rhx grove.provision --what 1.8.tmpfiles --mode apply" >&2
    failed=1
  fi

  return $failed
}
