#!/usr/bin/env bash
######################################################################
# .what = prove the watchdog's two files match this checkout, and that its
#         unit is enabled AND active
#
# ⚠️ .why the unit state is its own claim
#   - both files can be byte-perfect while the unit is stopped or failed
#   - ⇒ every file check passes, no probe runs, and the next stall waits for
#     a human again, with its state lost again
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_1_11_wifi_provision_verify() {
  local unit="$GROVE_PROVISION_1_11_WIFI_WATCHDOG_UNIT"
  local fix="sudo -v && rhx grove.provision --what 1.11.wifi --mode apply"

  # 0. the same decline as the upsert — no reader, no claim
  if ! command -v nmcli >/dev/null 2>&1; then
    echo "   🌙 no NetworkManager on this box — no watchdog owed"
    return 0
  fi
  if [[ "$(grove_provision_1_11_wifi_has_radio)" == no ]]; then
    echo "   🌙 no wifi radio on this box — no watchdog owed"
    return 0
  fi

  local failed=0

  # 1. the two files match this checkout
  local pair name rest dst src
  for pair in "${GROVE_PROVISION_1_11_WIFI_WATCHDOG_PAIRS[@]}"; do
    name="${pair%%:*}"; rest="${pair#*:}"; dst="${rest%:*}"
    src="$GROVE_SRC/machine/$name"
    if [[ ! -f "$dst" ]]; then
      echo "   ✋ $name is absent from $dst" >&2
      echo "      fix: $fix" >&2
      failed=1
    elif cmp -s "$src" "$dst"; then
      echo "   • $dst matches this checkout ✔"
    else
      echo "   ✋ the installed $dst DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      fix: $fix" >&2
      failed=1
    fi
  done

  # 2. THE claim — the watch runs now, and returns after a reboot
  local active enabled
  active="$(systemctl is-active "$unit" 2>/dev/null)"
  enabled="$(systemctl is-enabled "$unit" 2>/dev/null)"
  if [[ "$active" == active ]]; then
    echo "   • $unit is active ✔"
  else
    echo "   ✋ $unit is '${active:-absent}', not active" >&2
    echo "      ⇒ no probe runs, so a silent stall waits for a human, and its state is lost" >&2
    echo "      read why: journalctl -u $unit -n 30" >&2
    echo "      fix: $fix" >&2
    failed=1
  fi
  if [[ "$enabled" == enabled ]]; then
    echo "   • $unit is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ $unit is '${enabled:-absent}', not enabled" >&2
    echo "      fix: $fix" >&2
    failed=1
  fi

  return $failed
}
