#!/usr/bin/env bash
######################################################################
# prove.idle-check-clamp-bites-the-legacy-check — the idle-check clamp goes red
# on the check it replaced, on every arm that check fails
#
# .what = runs `prove.idle-check-counts-every-crew` with `IDLE_CHECK` at the
#         frozen bytes in `prove.idle-check-counts-every-crew.legacy.fixture` —
#         the check ahbode/infrastructure wrote at first boot, before this fix —
#         and reads the clamp's machine record (`<arm> pass|fail`, one per arm)
#
# .why a frozen copy, never a hand swap
#   - a clamp that once went red by hand can go vacuous later, and no run notices
#   - with the old bytes in the repo, every run re-proves that the clamp bites
#
# .why a machine record, never a scrape of the clamp's prose
#   - a reformat of the clamp's tree output cannot blind this play
#   - an arm the clamp grows with no class below fails here, so nobody adds an
#     arm without a word on whether the old check should fail it
#
# .the arms the old check must fail
#   worktree, mainclone  it reads only `~/.claude/projects`, never a crew's trace
#   duct, pgrepreal      it reads no tmux server, and names no server comm
#   pipe                 `sort -rn | head -1` breaks its pipe under ignored SIGPIPE
#   unreadable, refused, ioerror, noboot, moved, ptsunread   it swallows every read error, and sleeps
#   human, boot, edgehold  it holds, and prints no `hold` line to say why
#   keystroke, output    it reads a pts's mtime, so it sleeps on a keystroke and holds on output
#   *.line, counts       it words the sleep verdict another way, and names no stir and no count
#   imdsempty, awsrefused, noaws(.fix)  its stop act fails with no qualified malfunction line
#   future(.why)         a trace stamped ahead pins it awake, in silence
#   freshunread          a blind source beside a fresh trace is silent, and exits 0
#   dropowner, notmux, pgrepfault, hung, budget(.why)   it dials no duct, as its owner or at all
#   record(.loud)        it leaves no record a camper can read
#   recordnodir, recordnorename   it writes no record, so it says no failed write
#   unswept(.why), scope it counts no tmux server, so one off the sweep is silent
#   findkill(.why)       a find killed with no word reads as a clean, short sweep
#   hostilename          it reads no socket name, so names none — with or without its bytes
#   linkedroot, codex    it walks no symlinked root, and reads no codex session
#   junkduct(.why), mismatch(.why), bornmidsweep   it dials no duct, so it sleeps under each
#   slowwalk(.act), actlate(.act)   it bounds no read, so a slow walk ends in a stop act
#   sleeprecord          it leaves no record of the sleep a wake would read
#   hostilepath, hostilename.benign   it reads no error text, so no name can steer it — and none is loud
#   traceowner           it walks every root as root, never as the root's owner
#   wakegap, wakecarry, wakebadrecord   it reads no last tick, so a box just woken from a freeze reads idle
#
#   wakeover (green)     a wake past the limit holds naught, so the old check sleeps it as the new one does
#
# .and the arms it must pass — a red there would be a clamp defect, not a bite
#   idle, silentduct, stale, vanished, ptmx, edgesleep, lostserver   it sleeps a box with no stir, quietly
#   activity                            a tmux fact; no check runs in it
#
# usage:
#   rhx play.run --play prove.idle-check-clamp-bites-the-legacy-check
######################################################################
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEGACY="$HERE/prove.idle-check-counts-every-crew.legacy.fixture"
CLAMP="$HERE/prove.idle-check-counts-every-crew.play.sh"
FAILED=0

RED=(worktree mainclone duct pgrepreal pipe unreadable refused ioerror noboot moved human boot keystroke output
     idle.line silentduct.line stale.line vanished.line ptmx.line edgesleep.line counts
     imdsempty awsrefused noaws noaws.fix edgehold future future.why freshunread ptsunread
     dropowner notmux pgrepfault hung budget budget.why budget.fix record record.loud
     unswept unswept.why scope findkill findkill.why findkill.fix hostilename
     linkedroot codex junkduct junkduct.why lostserver.line mismatch mismatch.why bornmidsweep
     slowwalk slowwalk.act actlate actlate.act sleeprecord
     hostilepath hostilename.benign hostilename.benign.why traceowner wakegap wakegap.carry wakecarry wakebadrecord
     wakeover.line wakeover.drop awsrefused.sleep nohead unreadable.once recordnodir recordnorename)
GREEN=(idle silentduct stale vanished ptmx edgesleep activity lostserver wakeover)

[[ -f "$LEGACY" && -f "$CLAMP" ]] || { echo "✋ ConstraintError: the fixture or the clamp is absent beside this play"; exit 2; }

ARMS="$(mktemp)"
# the restore reports whether it took: a record that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap 'rm -f "$ARMS"; [[ -e "$ARMS" ]] && { echo "   ✋ residue SURVIVED — $ARMS"; exit 1; }' EXIT
OUT="$(IDLE_CHECK="$LEGACY" IDLE_ARMS="$ARMS" bash "$CLAMP" 2>&1)"; RC=$?

# .what = the verdict the clamp recorded for one arm: pass, fail, or empty
verdict() { awk -v a="$1" '$1 == a { print $2; exit }' "$ARMS"; }
# .what = is $1 one of the rest of the args?
among() { local x="$1"; shift; local y; for y in "$@"; do [[ "$x" == "$y" ]] && return 0; done; return 1; }

echo "🔭 does the clamp go red on the check this fix replaced?"
echo "   ├─ clamp exit: $RC"
[[ $RC -ne 0 ]] || { echo "   │  ✋ the clamp passed the old check — it bites none of its arms"; FAILED=1; }

for arm in "${RED[@]}"; do
  v="$(verdict "$arm")"
  if [[ "$v" == fail ]]; then echo "   ├─ ✔ '$arm' red on the old check"
  else echo "   ├─ ✋ '$arm' did not go red on the old check (saw '${v:-no record}')"; FAILED=1; fi
done
for arm in "${GREEN[@]}"; do
  v="$(verdict "$arm")"
  if [[ "$v" == pass ]]; then echo "   ├─ ✔ '$arm' green on the old check, as it should be"
  else echo "   ├─ ✋ '$arm' red on a behavior the old check holds (saw '${v:-no record}')"; FAILED=1; fi
done

# an arm the clamp recorded that this play has no class for
while read -r arm _; do
  among "$arm" "${RED[@]}" "${GREEN[@]}" && continue
  echo "   ├─ ✋ '$arm' has no class here — say whether the old check must fail it"; FAILED=1
done < "$ARMS"

# an IDLE_CHECK run compares no snap, and must say so — a silent drop reads as a match
if [[ "$OUT" == *"snapshot not compared: IDLE_CHECK names another copy"* ]]; then
  echo "   ├─ ✔ the clamp said aloud that it compared no snapshot for another copy"
else echo "   ├─ ✋ the clamp dropped its snapshot compare in silence"; FAILED=1; fi

# the ledger snap: every arm's verdict on the old check, in the clamp's run order. the old bytes
# are frozen, so a ledger that moves is a clamp that changed what it measures — shown in review
# a title, a legend, and totals ride above the rows, so the ledger reads alone in a diff
SNAP="# the clamp's arms, run against the check this fix replaced (prove.idle-check-counts-every-crew.legacy.fixture)
# red   = the old check fails the arm: a crew it misses, a source it reads in silence, or a verdict
#         or message shape it lacks — each a claim of the new check, never a sleep bug apiece
# green = the old check passes it: a behavior both checks hold
# an arm with a suffix (.line .why .fix .act .carry …) is a second claim inside the arm it names
# totals: $(awk '$2 == "fail" { r++ } $2 != "fail" { g++ } END { printf "%d red, %d green", r, g }' "$ARMS")
$(awk '{ print $1 " " ($2 == "fail" ? "red" : "green") }' "$ARMS")"$'\n'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.idle-check-clamp-bites-the-legacy-check.snap" name=ledger actual="$SNAP" || FAILED=1

echo "   └─ the old check, as the clamp read it"
printf '%s\n' "$OUT" | grep -E "arm '|✋|✔" | head -50 | sed 's/^/      │ /'

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the clamp bites the old check on every arm it fails, and spares the ones it holds"
else
  echo "✋ the clamp did NOT bite as declared — read the arms above"
fi
exit "$FAILED"
