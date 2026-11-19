#!/usr/bin/env bash
######################################################################
# .what = for a grove and its `.ground` seat: the seat the registry names, and the
#         seat ssh WILL dial for the same alias — side by side, with a verdict
#
# .why  = 📜 2026-11-18: a registry said `camper` while ssh dialed `ground`, for days,
#         and no command errored. every dial now heals or refuses through
#         `grove_ssh_seat_ready`; this is the READ a human or a clone asks first,
#         through the same reader, so the two can never disagree
#
# usage:
#   rhx git.grove.seat.get <grove>
#
# guarantee:
#   - READ-ONLY: it writes no alias and dials no box (`ssh -G` reads local config)
#   - exit 0 when every seat dials what the registry names; exit 2 when one does not
######################################################################

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.ssh.operations.sh"

GROVE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      echo "🔭 git.grove.seat.get — the seat the registry names vs the seat ssh dials"
      echo ""
      echo "usage:"
      echo "  rhx git.grove.seat.get <grove>"
      echo ""
      echo "example:"
      echo "  rhx git.grove.seat.get grove-ahbode-hetzner-v20261119"
      exit 0 ;;
    --repo|--role|--skill) shift 2 ;;
    -*) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx git.grove.seat.get --help" >&2; exit 2 ;;
    *) GROVE="$1"; shift ;;
  esac
done
[[ -n "$GROVE" ]] || { echo "✋ ConstraintError: no grove named" >&2; echo "   fix: rhx git.grove.seat.get <grove>   (see rhx git.grove.list)" >&2; exit 2; }

forest="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves"
[[ -f "$forest/$GROVE.json" ]] || { echo "✋ ConstraintError: grove '$GROVE' is not registered" >&2; echo "   fix: rhx git.grove.list" >&2; exit 2; }

echo "🔭 git.grove.seat.get $GROVE"
drift=0
seats=("$GROVE"); [[ -f "$forest/$GROVE.ground.json" ]] && seats+=("$GROVE.ground")
for i in "${!seats[@]}"; do
  name="${seats[$i]}"; reg="$forest/$name.json"
  alias="$(jq -r '.sshAlias // .name' "$reg")"
  want="$(jq -r '"\(.user // "?")@\(.host // "<its own Host block>"):\(.port // 22)"' "$reg")"
  got="$(grove_ssh_seat_effective "$alias")"
  glyph="├─"; (( i == ${#seats[@]} - 1 )) && glyph="└─"
  if [[ "$got" == "$want" || ( "$want" == *"<its own Host block>"* && "${got%%@*}" == "${want%%@*}" ) ]]; then
    echo "   $glyph $name ✔ $got"
  else
    echo "   $glyph $name ✋ registry $want · ssh dials $got"
    drift=1
  fi
done
(( drift == 0 )) && exit 0
echo ""
echo "✋ ConstraintError: a seat dials another place than the registry names" >&2
echo "   fix: the next dial heals a tailnet seat on its own; to heal it now —" >&2
echo "     rhx git.grove.wake $GROVE" >&2
exit 2