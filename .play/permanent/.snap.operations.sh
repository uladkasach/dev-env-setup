#!/usr/bin/env bash
######################################################################
# .what = snap the whole message a play arm rendered, and hold it against
#         the snap on disk
#
# .why  a play grades each ✋ / 🌙 / ✔ by the one phrase a human acts on.
#       that proves the phrase, and shows a reviewer none of the rest. a snap
#       keeps the whole rendered message in the diff, so a PR shows what a
#       human meets, and a drift in any line of it reddens the play
#       (`rule.require.snapshots`: a phrase assertion AND a snap, never one)
#
# usage (sourced by a play):
#   source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"
#   play_snap_assert arm="V1" rendered="$out" mask="$FIX"
#
# snaps live at  .play/permanent/__snaps__/<play>/<arm>.snap
#
# guarantee:
#   - each `mask=` value (repeatable) becomes `<fixture>` in the snap, so a
#     temp path never makes a snap differ run to run
#   - PLAY_RESNAP=1 (`rhx play.run --resnap`) rewrites each snap from this run
#   - a match is silent; the arm's own ✔ reports it
#   - an absent snap FAILS unless PLAY_RESNAP=1: a snap that never shipped pins
#     naught, so a clone or a box whose `__snaps__/` lacks it must go red, never
#     mint one and pass. the first mint is a deliberate `--resnap`
#   - a differ prints the diff and returns 1
######################################################################

# the play's slug, from the file bash was handed (play.run runs `bash <path>`)
PLAY_SNAP_SLUG="$(basename "$0" .play.sh)"
PLAY_SNAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/__snaps__/$PLAY_SNAP_SLUG"
PLAY_SNAP_SEEN=" "

play_snap_assert() {
  local arm="" rendered="" masks=() kv
  for kv in "$@"; do
    case "$kv" in
      arm=*) arm="${kv#arm=}" ;;
      rendered=*) rendered="${kv#rendered=}" ;;
      mask=*) [[ -n "${kv#mask=}" ]] && masks+=("${kv#mask=}") ;;
      *) echo "   💥 MalfunctionError: play_snap_assert: unknown arg '$kv'" >&2; return 1 ;;
    esac
  done
  [[ -n "$arm" ]] || { echo "   💥 MalfunctionError: play_snap_assert needs arm=" >&2; return 1; }

  # mask each fixture path, longest first, so a nested path never leaves a stub
  local m masked="$rendered"
  while IFS= read -r m; do
    [[ -n "$m" ]] && masked="${masked//"$m"/<fixture>}"
  done < <(printf '%s\n' "${masks[@]+"${masks[@]}"}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

  local snap="$PLAY_SNAP_DIR/$arm.snap"
  mkdir -p "$PLAY_SNAP_DIR"

  # an arm written once this run is compared from then on, so two grades of one arm
  # that rendered two different messages redden even under a resnap
  if [[ "$PLAY_SNAP_SEEN" != *" $arm "* && "${PLAY_RESNAP:-0}" == 1 ]]; then
    PLAY_SNAP_SEEN+="$arm "
    printf '%s\n' "$masked" > "$snap"
    echo "   │  ✨ snap written: __snaps__/$PLAY_SNAP_SLUG/$arm.snap"
    return 0
  fi

  # an absent snap is no match: the arm's message is pinned nowhere
  [[ -f "$snap" ]] || {
    echo "   │  ✋ ConstraintError: no snap on disk: __snaps__/$PLAY_SNAP_SLUG/$arm.snap" >&2
    echo "   │     ⇒ the message this arm renders is pinned nowhere, so no drift in it can redden" >&2
    echo "   │     fix: rhx play.run --play $PLAY_SNAP_SLUG --resnap, then read each new snap" >&2
    return 1
  }

  # a match is silent: the arm's own ✔ above already reports it
  diff -u "$snap" <(printf '%s\n' "$masked") >/dev/null && return 0

  echo "   │  ✋ snap differs: __snaps__/$PLAY_SNAP_SLUG/$arm.snap" >&2
  # labels, not paths and mtimes, head the diff: a temp fd and a clock are no part of the drift
  diff -u --label "snap: $arm" --label "this run: $arm" "$snap" <(printf '%s\n' "$masked") | sed 's/^/   │     /' >&2
  echo "   │     ⇒ if the change is meant: rhx play.run --play $PLAY_SNAP_SLUG --resnap, then review the diff" >&2
  return 1
}
