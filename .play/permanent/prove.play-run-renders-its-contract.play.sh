#!/usr/bin/env bash
######################################################################
# .what = snap every message `play.run` renders to a human: --help, --list,
#         the --all tally, each per-play verdict, and each refusal
#
# .why this play exists
#   - `play.run` is the runner every proof in this repo reports through, and its
#     --all tally is what a human reads to judge a branch. a drift in any of its
#     rows reddened no test, and no diff showed it
#
# .the arms — a fixture repo of stub plays, never this repo's own tree
#   - H. --help                    → the usage block, exit 0
#   - L. --list                    → every tracked stub, exit 0
#   - A. --all --within 2          → the tally: 1 passed, 1 failed, 2 declined or timed out,
#     2 refused by verb (never run), exit 1
#   - P1/P2/P3. one play passes / fails / declines → exit 0 / 1 / 2
#   - T. a play past its bound     → a timeout row, exit 2
#   - R. a repair.* play           → refused by verb, exit 2
#   - V. an unknown verb           → refused by verb, exit 2
#   - E1..E6. bad input            → --play with no value, an unknown flag, an
#     absent slug, a path for a slug, no subject, --all beside --play; each exit 2
#   - U1/U2. an untracked play     → --list warns, --play refuses; each exit 2
#   - S1..S4. the snap harness     → an absent snap fails (1), --resnap writes it (0),
#     a match holds (0), a drift fails (1)
#
# .what is real and what is a fixture
#   - the runner is this repo's own `play.run.sh`, copied byte for byte into a
#     temp git repo, since it reads its play dir from the checkout it sits in
#   - the plays are stubs; the subject here is the runner, never a play
#
# usage:
#   rhx play.run --play prove.play-run-renders-its-contract
#
# exit:
#   0 = every arm holds
#   1 = an arm failed
#   2 = no checkout found, or the runner is absent
######################################################################

set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -d "$self/.agent" ]] && { printf '%s' "$self"; return 0; }
  [[ -d "$PWD/.agent" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }

_skill_rel=".agent/repo=.this/role=any/skills/play.run.sh"
[[ -f "$_root/$_skill_rel" ]] || { echo "   ✋ ConstraintError: no runner at $_root/$_skill_rel" >&2; exit 2; }

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

echo "🔎 prove.play-run-renders-its-contract"
echo "   └─ root: $_root"
echo ""

# the fixture repo: the runner's own bytes, and a play dir of stubs in the index
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
FIX_REAL="$(cd "$FIX" && pwd -P)"
mkdir -p "$FIX/$(dirname "$_skill_rel")" "$FIX/.play/permanent"
cp "$_root/$_skill_rel" "$FIX/$_skill_rel"
RUNNER="$FIX/$_skill_rel"

_stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$FIX/.play/permanent/$1.play.sh"; }
_stub prove.stub-passes  'echo "   • stub holds ✔"; exit 0'
_stub prove.stub-fails   'echo "   ✋ stub broke" >&2; exit 1'
_stub prove.stub-declines 'echo "   🌙 stub subject absent"; exit 2'
_stub prove.stub-hangs   'exec sleep 30'
_stub repair.stub-mends  'exit 0'
_stub lint.stub-reads    'exit 0'
git -C "$FIX" init -q
git -C "$FIX" add -- .play/permanent "$_skill_rel"

FAILED=0

# .what = run the runner with $@, then grade its exit code, one phrase, and the whole message
_arm() {
  local arm="$1" want_rc="$2" phrase="$3"; shift 3
  local out rc=0
  # this play's own --resnap must not reach the runner under proof: each inner run sets its own
  out="$(env -u PLAY_RESNAP bash "$RUNNER" "$@" 2>&1)" || rc=$?
  if [[ "$rc" -ne "$want_rc" ]]; then
    echo "   ✋ $arm: play.run $* exited $rc, wanted $want_rc" >&2; FAILED=1; return
  fi
  if [[ "$out" != *"$phrase"* ]]; then
    echo "   ✋ $arm: play.run $* did not say: $phrase" >&2; FAILED=1; return
  fi
  play_snap_assert arm="$arm" rendered="$out" mask="$FIX_REAL" mask="$FIX" || { FAILED=1; return; }
  echo "   ✔ $arm: play.run $* → exit $rc, says '$phrase'"
}

_arm H  0 "usage:"                              --help
_arm L  0 "6 play(s)"                           --list
_arm A  1 "passed: 1 of 6"                      --all --within 2
_arm P1 0 "🌲 prove.stub-passes ✔"              --play prove.stub-passes
_arm P2 1 "prove.stub-fails failed (exit 1)"    --play prove.stub-fails
_arm P3 2 "prove.stub-declines declined"        --play prove.stub-declines
_arm T  2 "did not finish within 2s"            --play prove.stub-hangs --within 2
_arm R  2 "is a repair play"                    --play repair.stub-mends
_arm V  2 "does not name a verb"                --play lint.stub-reads
_arm E1 2 "--play needs a value"                --play
_arm E2 2 "unknown flag: --bogus"               --bogus
_arm E3 2 "no play named 'prove.stub-absent'"   --play prove.stub-absent
_arm E4 2 "named by SLUG, never by path"        --play ../prove.stub-passes
_arm E5 2 "name a play"
_arm E6 2 "name two subjects"                   --all --play prove.stub-passes
_arm E7 2 "--within needs a value"              --play prove.stub-passes --within

# an untracked play: listed by count only, and refused by name
_stub prove.stub-planted 'exit 0'
_arm U1 2 "1 untracked .play.sh file(s)"        --list
_arm U2 2 "NOT in this repo's index"            --play prove.stub-planted

# the snap harness itself: a stub that snaps one message through this repo's own
# `.snap.operations.sh`, so a revert of either snap guarantee reddens here
cp "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh" "$FIX/.play/permanent/.snap.operations.sh"
_stub prove.stub-snaps 'source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"
play_snap_assert arm=S rendered="${STUB_MSG:-the stub message}" || exit 1
echo "   • stub snap holds ✔"'
git -C "$FIX" add -- .play/permanent/.snap.operations.sh .play/permanent/prove.stub-snaps.play.sh
_arm S1 1 "no snap on disk"                     --play prove.stub-snaps
_arm S2 0 "snap written"                        --play prove.stub-snaps --resnap
_arm S3 0 "stub snap holds ✔"                   --play prove.stub-snaps
export STUB_MSG="a drifted stub message"
_arm S4 1 "snap differs"                        --play prove.stub-snaps
unset STUB_MSG

echo ""
if [[ "$FAILED" -ne 0 ]]; then
  echo "🐚 prove.play-run-renders-its-contract: an arm failed"
  exit 1
fi
echo "🌲 play.run renders each verdict and each refusal as its snap holds"
