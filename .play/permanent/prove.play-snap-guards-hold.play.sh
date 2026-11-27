#!/usr/bin/env bash
######################################################################
# prove.play-snap-guards-hold — the shared snapshot helper writes a first snap,
# passes a match, refuses a drift loud, rewrites only on an explicit resnap, and
# under CI neither writes nor rewrites a baseline
#
# .what = drives `.play/permanent/play.snap.operations.sh` `play_snap_verify`
#         through each of its branches, against a snap dir in a temp root
#
# .why its own play
#   - every play that snaps leans on this one helper, and each calls it once,
#     against a committed snap, with CI and GROVE_RESNAP unset — so only the
#     match branch ever runs. the two CI refusals are the guards that must hold
#     when nobody watches, and no other play proves they fire
#
# .the arms
#   first      no snap, no CI               → exit 0, "snapshot written", the file holds the text
#   match      the same text again          → exit 0, "snapshot matches"
#   drift      other text                   → exit 1, 💥 + the diff + the `--resnap` step; file unchanged
#   resnap     other text, GROVE_RESNAP=1   → exit 0, "snapshot rewritten"; the file holds the new text
#   cimatch    a match under CI             → exit 0 — CI still compares, it only never writes
#   ciresnap   GROVE_RESNAP=1 under CI      → exit 1, 💥 "under CI"; the file unchanged
#   ciabsent   no snap, CI set              → exit 1, 💥 "CI is set"; no file written
#   badarg     an arg the helper does not know → exit 1, 💥 names it
#   noname     no name=                     → exit 1, 💥 names name=, and only it
#   nodir      no dir=                      → exit 1, 💥 names dir=, and only it
#   noboth     neither                      → exit 1, 💥 names both
#   longdrift  a drift past 40 diff lines   → exit 1, the cut says how many lines it did not show
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir, removed by a trap
#
# usage:
#   rhx play.run --play prove.play-snap-guards-hold
######################################################################
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$HERE/play.snap.operations.sh"
T=""
# the restore reports whether it took: a temp dir that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap '[[ -n "$T" ]] && rm -rf "$T"; [[ -n "$T" && -e "$T" ]] && { echo "   ✋ residue SURVIVED — $T"; exit 1; }' EXIT
[[ -f "$HELPER" ]] || { echo "✋ ConstraintError: no snap helper at $HELPER — this play measures the real file"; exit 2; }

T="$(mktemp -d)"
DIR="$T/x.snap"
FILE="$DIR/t.snap"
FAILED=0

# .what = call the helper in a clean subshell, with only the env this arm names; stdout and stderr apart
# .why `env -u`: a CI or GROVE_RESNAP this play inherits must never leak into an arm that wants it unset
OUT=""; ERR=""; RC=""
call() {
  local envs=() text="$2"
  read -ra envs <<< "$1"
  OUT="$(env -u CI -u GROVE_RESNAP "${envs[@]}" bash -c 'source "$1"; play_snap_verify dir="$2" name=t actual="$3"' _ "$HELPER" "$DIR" "$text" 2>"$T/err")"; RC=$?
  ERR="$(cat "$T/err")"
}
# .what = judge an arm: judge <arm> <ok 0|1> <claim>; each arm's output joins the snap, masked
SNAP=""
judge() {
  echo "   ├─ arm '$1'"
  if [[ "$2" -eq 0 ]]; then echo "   │  ✔ $3"
  else echo "   │  ✋ $3 did NOT hold"; printf '%s\n' "exit=$RC" "$OUT" "$ERR" | sed 's/^/   │     │ /'; FAILED=1; fi
  SNAP+="## $1 (exit $RC)"$'\n'"### stdout"$'\n'"${OUT//$T/<tmp>}"$'\n'"### stderr"$'\n'"${ERR//$T/<tmp>}"$'\n\n'
}

echo "🔭 does the snap helper write, match, refuse, and rewrite as it says?"

call "" "line one"
[[ "$RC" -eq 0 && "$OUT" == *"snapshot written: t"* && "$(cat "$FILE" 2>/dev/null)" == "line one" ]]
judge first $? "a first run writes the snap, and says so"

call "" "line one"
[[ "$RC" -eq 0 && "$OUT" == *"snapshot matches: t"* ]]
judge match $? "the same text passes, and says so"

call "" "line two"
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: 't' drifted from its snapshot"* && "$ERR" == *"< line two"* \
  && "$ERR" == *"--resnap"* && "$(cat "$FILE")" == "line one" ]]
judge drift $? "a drift fails loud with its diff and the resnap step, and leaves the snap as it was"

call "GROVE_RESNAP=1" "line two"
[[ "$RC" -eq 0 && "$OUT" == *"snapshot rewritten: t (GROVE_RESNAP=1)"* && "$(cat "$FILE")" == "line two" ]]
judge resnap $? "an explicit resnap rewrites the snap, and says so"

call "CI=1" "line two"
[[ "$RC" -eq 0 && "$OUT" == *"snapshot matches: t"* ]]
judge cimatch $? "under CI a match still passes — CI compares, it only never writes"

call "CI=1 GROVE_RESNAP=1" "line three"
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: GROVE_RESNAP=1 under CI"* && "$(cat "$FILE")" == "line two" ]]
judge ciresnap $? "a resnap under CI is refused, and the snap is untouched"

rm -rf "$DIR"
call "CI=1" "line one"
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: no snapshot at"*"CI is set"* && ! -e "$FILE" ]]
judge ciabsent $? "an absent snap under CI is a 💥, never a write"

OUT="$(bash -c 'source "$1"; play_snap_verify dir="$2" name=t bogus=1 actual=x' _ "$HELPER" "$DIR" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
[[ "$RC" -eq 1 && "$ERR" == *"unknown arg 'bogus'"* ]]
judge badarg $? "an arg the helper does not know is named, never ignored"

OUT="$(bash -c 'source "$1"; play_snap_verify dir="$2" actual=x' _ "$HELPER" "$DIR" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: the snapshot check was called with no name= —"* && "$ERR" != *"no dir="* ]]
judge noname $? "a call with no name= is refused by that name, never written under an empty name"

OUT="$(bash -c 'source "$1"; play_snap_verify name=t actual=x' _ "$HELPER" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: the snapshot check was called with no dir= —"* && "$ERR" != *"name="*"—"* ]]
judge nodir $? "a call with no dir= is refused by that name, never written under the cwd"

OUT="$(bash -c 'source "$1"; play_snap_verify actual=x' _ "$HELPER" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"
[[ "$RC" -eq 1 && "$ERR" == *"called with no dir= and name= —"* ]]
judge noboth $? "a call with neither names both"

# a drift past the 40-line window says how much it cut
call "" "$(seq 1 30)"
call "" "$(seq 101 130)"
[[ "$RC" -eq 1 && "$ERR" == *"… 22 more diff line(s) not shown"* ]]
judge longdrift $? "a drift cut to 40 lines names how many it did not show"

# this play's own transcript, held by the helper it proves — the arms above are what make that safe
# shellcheck source=/dev/null
source "$HELPER" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.play-snap-guards-hold.snap" name=transcript actual="$SNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the snap helper writes, matches, refuses a drift, rewrites only on resnap, and never writes under CI"
else
  echo "✋ the snap helper did NOT hold its contract — read the arms above"
fi
exit "$FAILED"
