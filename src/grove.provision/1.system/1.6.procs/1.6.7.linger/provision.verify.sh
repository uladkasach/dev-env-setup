#!/usr/bin/env bash
######################################################################
# .what = prove every human seat on this box lingers
#
# .why one claim PER SEAT, never one for `$USER`
#   - the seat that runs the verify is one seat of several; a crew may live
#     under any of them, and a ✔ for the observer says naught of the rest
#
# guarantee:
#   - READ-ONLY. it reads the logind record dir and the passwd roster
#
# exit:
#   0 = every seat lingers
#   1 = a seat does not linger, and which is named — on every tier alike
######################################################################

grove_provision_1_6_7_linger_provision_verify() {
  local unlingered=() seat
  while read -r seat; do
    [[ -n "$seat" ]] && unlingered+=("$seat")
  done < <(grove_provision_1_6_7_linger_unlingered)

  if [[ ${#unlingered[@]} -eq 0 ]]; then
    echo "   • every human seat lingers ✔"
    return 0
  fi

  for seat in "${unlingered[@]}"; do
    echo "   ✋ ConstraintError: $seat does not linger" >&2
    echo "      ⇒ its user manager and every crew scope under it end at its last" >&2
    echo "        logout — on a cloud grove, when the duct's last pane closes; on a" >&2
    echo "        laptop, when the desktop session ends" >&2
  done
  echo "      fix: sudo -v && rhx grove.provision --what 1.6.7.linger --mode apply" >&2
  echo "           the seat with root grants it to every seat" >&2
  return 1
}
