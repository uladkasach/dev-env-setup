#!/usr/bin/env bash
######################################################################
# .what = grant linger to every human seat without it
#
# guarantee:
#   - idempotent: each seat is READ before a grant, and a lingered seat is left alone
#   - a seat with no root DECLINES (🌙); the verify still ✋s per unlingered seat
#   - a failed grant is a ✋ that names the seat, never a 🌙
######################################################################

grove_provision_1_6_7_linger_provision_upsert() {
  local unlingered=() seat
  while read -r seat; do
    [[ -n "$seat" ]] && unlingered+=("$seat")
  done < <(grove_provision_1_6_7_linger_unlingered)

  if [[ ${#unlingered[@]} -eq 0 ]]; then
    echo "   • every human seat lingers ✔"
    return 0
  fi

  bundle.root.owns "linger for this box's seats" \
    "no linger: ${unlingered[*]}" || return 0

  local failed=0
  for seat in "${unlingered[@]}"; do
    grove_provision_1_6_7_linger_seat_grant "$seat" || failed=$(( failed + 1 ))
  done

  [[ "$failed" -eq 0 ]]
}

# .what = grant linger to one seat, then READ it back — the grant's own exit
#   code is never the verdict; the logind record is
grove_provision_1_6_7_linger_seat_grant() {
  local seat="$1"
  if sudo loginctl enable-linger "$seat" && grove_provision_1_6_7_linger_seat_lingers "$seat"; then
    echo "   • $seat lingers, so its crews outlive its last logout ✔"
    return 0
  fi
  echo "   ✋ could not grant linger to $seat" >&2
  echo "      ⇒ its user manager, and every crew scope under it, ends at its" >&2
  echo "        last logout — on a grove, when the duct closes" >&2
  echo "      read why: sudo loginctl enable-linger $seat" >&2
  return 1
}
