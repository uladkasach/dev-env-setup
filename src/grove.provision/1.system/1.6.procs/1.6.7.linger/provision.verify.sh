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
  # an empty roster proves no seat lingers — a ✔ over zero seats is the very silence
  #   this bundle exists to end
  local roster=() unlingered=() seat
  while read -r seat; do
    [[ -n "$seat" ]] && roster+=("$seat")
  done < <(grove_provision_1_6_7_linger_roster)
  if [[ ${#roster[@]} -eq 0 ]]; then
    echo "   ✋ ConstraintError: the passwd roster names no human seat, so no seat's linger could be read" >&2
    echo "      ⇒ a box with crews has at least one; an empty read means the roster itself is unread" >&2
    echo "      read why: getent passwd" >&2
    return 1
  fi

  while read -r seat; do
    [[ -n "$seat" ]] && unlingered+=("$seat")
  done < <(grove_provision_1_6_7_linger_unlingered)

  if [[ ${#unlingered[@]} -eq 0 ]]; then
    echo "   • every human seat lingers: ${roster[*]} ✔"
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
  echo "           (on a grove: run it on the ground seat, which holds sudo)" >&2
  return 1
}
