#!/usr/bin/env bash
######################################################################
# .what
#   - prove the lock units match this checkout
#   - and that the timer is actually ACTIVE
#
# ⚠️ .the timer's state is its own claim
#   - the two units can be byte-perfect while the timer is disabled or masked
#   - then every file check passes, NO lock fires, and the box reports configured
#   - `systemctl --user is-active` is the only reader of that fact
#
# ⚠️ .an inactive timer HERE means the vault is open
#   - `1.2.power` already turned off screen-lock and suspend on this box
#   - ⇒ the three are only safe as a set
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_6_5_onepassword_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no vault on $GROVE_ENV_SERVER, so no lock timer is expected"
    return 0
  fi

  local failed=0
  local unit_dir="$HOME/.config/systemd/user"

  ####################################################################
  # 1. both units exist
  #
  #   - a timer with no service fires into an absent unit
  #   - systemd reports that as a FAILED job, so the timer's side looks healthy
  ####################################################################
  local unit
  for unit in 1password-lock.service 1password-lock.timer; do
    if [[ -f "$unit_dir/$unit" ]]; then
      echo "   • $unit declared ✔"
    else
      echo "   ✋ $unit is absent from $unit_dir" >&2
      echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
      echo "             --include onepassword" >&2
      failed=1
    fi
  done

  ####################################################################
  # 2. the service names the ABSOLUTE binary
  #
  #   - a unit inherits no login PATH, so a bare `1password` loads and enables
  #   - it then fails at every fire with a quiet status=203, and the vault stays open
  ####################################################################
  if [[ -f "$unit_dir/1password-lock.service" ]]; then
    if grep -F 'ExecStart=/usr/bin/1password --lock' \
      "$unit_dir/1password-lock.service" >/dev/null 2>&1; then
      echo "   • the lock service names the absolute binary ✔"
    else
      echo "   ✋ 1password-lock.service does NOT name /usr/bin/1password --lock" >&2
      echo "      ⇒ a unit inherits no login PATH, so a bare '1password' loads and" >&2
      echo "        enables cleanly, then fails at every fire with status=203 —" >&2
      echo "        quietly, while the vault stays open" >&2
      echo "      read it: cat $unit_dir/1password-lock.service" >&2
      echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
      echo "             --include onepassword" >&2
      failed=1
    fi
  fi

  ####################################################################
  # 3. THE claim — the timer is live NOW and survives a reboot
  #
  # ⚠️ .BOTH `is-active` and `is-enabled`, since neither implies the other
  #        is-active  → is it live in THIS boot
  #        is-enabled → will it come back after a REBOOT
  #   - a `systemctl --user start` with no `enable` passes today and is gone tomorrow
  ####################################################################
  local state_active state_enabled
  state_active="$(systemctl --user is-active 1password-lock.timer 2>/dev/null)"
  state_enabled="$(systemctl --user is-enabled 1password-lock.timer 2>/dev/null)"

  if [[ "$state_active" == "active" ]]; then
    local next
    next="$(systemctl --user list-timers 1password-lock.timer --no-pager 2>/dev/null | head -2 | tail -1)"
    echo "   • 1password-lock.timer is active ✔"
    [[ -n "$next" ]] && echo "     next: $next"
  else
    echo "   ✋ 1password-lock.timer is '${state_active:-absent}', not active" >&2
    echo "      ⇒ every file above can be byte-perfect and NO lock ever fires" >&2
    echo "      ⇒ COSMIC raises no idle signal, so the app's own auto-lock is" >&2
    echo "        already inert — this timer is what replaces it" >&2
    echo "      ⇒ and 1.2.power turns off screen-lock and suspend on this box, so" >&2
    echo "        an unattended laptop keeps an OPEN vault with no other guard" >&2
    echo "      read why: systemctl --user status 1password-lock.timer" >&2
    echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
    echo "             --include onepassword" >&2
    failed=1
  fi

  if [[ "$state_enabled" == "enabled" ]]; then
    echo "   • 1password-lock.timer is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ 1password-lock.timer is '${state_enabled:-absent}', not enabled" >&2
    echo "      ⇒ it may be active THIS boot and gone the next, so the vault stops" >&2
    echo "        auto-lock with every check above still green" >&2
    echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
    echo "             --include onepassword" >&2
    failed=1
  fi

  return $failed
}
