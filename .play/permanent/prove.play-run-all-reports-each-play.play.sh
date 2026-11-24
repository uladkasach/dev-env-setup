#!/usr/bin/env bash
######################################################################
# prove.play-run-all-reports-each-play — `play.run --all` gives one verdict per
# play, three counts that never fold a decline into a pass, a log per play, and
# the exit its header declares; `--resnap` reaches the play it runs
#
# .what = copies THIS checkout's `play.run.sh` into a temp git repo whose
#         `.play/permanent/` holds four tracked fixture plays — one that passes,
#         one that declines, one that fails, one that echoes GROVE_RESNAP — and
#         drives the runner there
#
# .why a temp repo, never this one
#   - the runner derives its play dir from its own file's checkout, so a copy in a
#     fixture repo runs a suite whose verdicts are known — and never recurses into
#     this repo's own suite, which holds this play
#
# .the arms
#   mixed      pass + decline + fail      → exit 1; ✔ / 🌙 / 💥 rows; `1 passed · 1 declined · 1 failed`
#   logs       the same run               → the summary and one log per play, under `.log/role=any/skill=play.run/what=all/`
#   declined   pass + decline             → exit 2; the decline is said to prove no claim
#   allpass    pass alone                 → exit 0, `every play passed`
#   twosubjects  `--all --play x`         → exit 2, `name two subjects`
#   resnap.on  `--play <probe> --resnap`  → the play reads GROVE_RESNAP=1
#   resnap.off `--play <probe>`           → the play reads it unset
#   empty      `--all`, no tracked play   → exit 2, never `every play passed`
#   unknownflag, playnovalue, withinnovalue, noplay, pathescape, notfound, notindex,
#   repairverb, wrongverb                         → exit 2, each with its own ✋ words
#   timeout, playdecline   → exit 2 under 🌙, the mark `--all` gives them: neither is a verdict
#   playfail   a single play that fails   → exit 1, `💥 MalfunctionError: <play> failed`
#   list.untracked `--list`, an untracked play beside → exit 2, ✋ with a count and no name
#   list       `--list`, a tracked suite  → exit 0, each name in a tree under its count
#   list.all, list.play  `--list` beside `--all` or `--play` → exit 2, `name two subjects`
#   help       `--help`                   → exit 0, the usage, options, and exit codes
#   logdirfail `--all`, no log dir can be made → exit 1, and no play runs
#   noplaydir  a checkout with no play dir → exit 2, never an empty pass
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir, removed by a trap
#
# usage:
#   rhx play.run --play prove.play-run-all-reports-each-play
######################################################################
set -uo pipefail
# the snap holds coreutils' own errors (mkdir, mv), whose quotes follow the locale: pin it
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$(cd "$HERE/../.." && pwd)/.agent/repo=.this/role=any/skills/play.run.sh"
T=""
# the restore reports whether it took: a temp dir that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap '[[ -n "$T" ]] && rm -rf "$T"; [[ -n "$T" && -e "$T" ]] && { echo "   ✋ residue SURVIVED — $T"; exit 1; }' EXIT
[[ -f "$RUNNER" ]] || { echo "✋ ConstraintError: no runner at $RUNNER — this play measures the real file"; exit 2; }
command -v git >/dev/null || { echo "✋ ConstraintError: no git on PATH — the runner reads its suite from git's index"; exit 2; }

T="$(mktemp -d)"
git -C "$T" init -q || { echo "💥 MalfunctionError: git could not init a fixture repo at $T"; exit 1; }
mkdir -p "$T/skills" "$T/.play/permanent"
cp "$RUNNER" "$T/skills/play.run.sh"
printf '#!/usr/bin/env bash\necho ok\nexit 0\n' > "$T/.play/permanent/prove.a-pass.play.sh"
printf '#!/usr/bin/env bash\necho "no subject here"\nexit 2\n' > "$T/.play/permanent/prove.b-decline.play.sh"
printf '#!/usr/bin/env bash\necho broke\nexit 1\n' > "$T/.play/permanent/prove.c-fail.play.sh"
printf '#!/usr/bin/env bash\necho "GROVE_RESNAP=${GROVE_RESNAP:-unset}"\nexit 0\n' > "$T/.play/permanent/prove.d-resnap.play.sh"
FAILED=0

# .what = stage exactly the named fixture plays; the runner reads its suite from the index
suite() {
  git -C "$T" rm -q --cached -r --ignore-unmatch .play >/dev/null
  local p; for p in "$@"; do git -C "$T" add ".play/permanent/prove.$p.play.sh"; done
}
# .what = run the copied runner, stdout and stderr apart; CI and GROVE_RESNAP never leak in
OUT=""; ERR=""; RC=""; RUNS=0
run() { OUT="$(env -u CI -u GROVE_RESNAP bash "$T/skills/play.run.sh" "$@" 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"; RUNS=$((RUNS + 1)); }
# .what = judge an arm; each run's output joins the snap once, under the first arm that judges it,
#   with the temp root and the log stamp masked
SNAP=""; KEPT=0
mask() { printf '%s' "$1" | sed -E -e "s#$T#<tmp>#g" -e 's#what=all/[^ ]+#what=all/<stamp>#g'; }
judge() {
  echo "   ├─ arm '$1'"
  if [[ "$2" -eq 0 ]]; then echo "   │  ✔ $3"
  else echo "   │  ✋ $3 did NOT hold"; printf '%s\n' "exit=$RC" "$OUT" "$ERR" | sed 's/^/   │     │ /'; FAILED=1; fi
  [[ "$RUNS" -gt "$KEPT" ]] || return 0
  KEPT=$RUNS
  SNAP+="## $1 (exit $RC)"$'\n'"### stdout"$'\n'"$(mask "$OUT")"$'\n'"### stderr"$'\n'"$(mask "$ERR")"$'\n\n'
}

echo "🔭 does play.run --all give one verdict per play, and the exit its header names?"

suite a-pass b-decline c-fail; run --all --within 30
[[ "$RC" -eq 1 && "$OUT" == *"├─ ✔ prove.a-pass"* && "$OUT" == *"├─ 🌙 prove.b-decline — declined or timed out"* \
  && "$OUT" == *"├─ 💥 prove.c-fail — failed (exit 1)"* && "$OUT" == *"└─ 1 passed · 1 declined · 1 failed"* \
  && "$ERR" == *"💥 MalfunctionError: 1 play(s) failed"* ]]
judge mixed $? "a pass, a decline, and a fail read as three rows and three counts, and exit 1"

LOGDIR="$(find "$T/.log/role=any/skill=play.run/what=all" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
[[ -n "$LOGDIR" && -f "$LOGDIR/summary.log" && -f "$LOGDIR/prove.a-pass.log" && -f "$LOGDIR/prove.c-fail.log" \
  && "$(cat "$LOGDIR/summary.log")" == *"1 passed · 1 declined · 1 failed"* && "$(cat "$LOGDIR/prove.c-fail.log")" == *"broke"* ]]
judge logs $? "the summary and one log per play land under .log/role=any/skill=play.run/what=all/"

suite a-pass b-decline; run --all --within 30
[[ "$RC" -eq 2 && "$OUT" == *"└─ 1 passed · 1 declined · 0 failed"* && "$ERR" == *"declined or timed out, so proved no claim"* ]]
judge declined $? "a decline with no fail exits 2, and is never folded into a pass"

suite a-pass; run --all --within 30
[[ "$RC" -eq 0 && "$OUT" == *"🌲 every play passed"* ]]
judge allpass $? "a suite that all passes exits 0"

run --all --play prove.a-pass
[[ "$RC" -eq 2 && "$ERR" == *"--all and --play name two subjects"* ]]
judge twosubjects $? "--all beside --play is refused, never one of the two guessed"

suite d-resnap; run --play prove.d-resnap --resnap
[[ "$RC" -eq 0 && "$OUT" == *"GROVE_RESNAP=1"* ]]
judge resnap.on $? "--resnap reaches the play as GROVE_RESNAP=1"
run --play prove.d-resnap
[[ "$RC" -eq 0 && "$OUT" == *"GROVE_RESNAP=unset"* ]]
judge resnap.off $? "with no --resnap, the play reads GROVE_RESNAP unset"

# an empty suite is a constraint, never a pass: zero rows would read as `every play passed`
suite; run --all --within 30
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: no tracked play in"* && "$OUT" != *"every play passed"* ]]
judge empty $? "an empty tracked suite exits 2 and never reports a pass"

# each refusal a caller can meet, with its exit and its words
run --bogus
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: unknown flag: --bogus"* && "$ERR" == *"valid: --play"* ]]
judge unknownflag $? "an unknown flag halts with the valid set"
run --play
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: --play needs a value"* ]]
judge playnovalue $? "a bare --play halts"
run --within
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: --within needs a value"* ]]
judge withinnovalue $? "a bare --within halts"
run
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: name a play"* ]]
judge noplay $? "no subject named halts, and names the three forms"
run --play ../x
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: a play is named by SLUG, never by path: '../x'"* ]]
judge pathescape $? "a path for a slug is refused outright"
run --play prove.zz-absent
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: no play named 'prove.zz-absent'"* ]]
judge notfound $? "an absent play is named, with where it looked"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.play/permanent/prove.e-untracked.play.sh"
run --play prove.e-untracked
[[ "$RC" -eq 2 && "$ERR" == *"is on disk and NOT in this repo's index"* && "$ERR" == *"git add .play/permanent/prove.e-untracked.play.sh"* ]]
judge notindex $? "an untracked play is refused, and the refusal names the git add"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.play/permanent/repair.f-fix.play.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/.play/permanent/fix.g-noverb.play.sh"
printf '#!/usr/bin/env bash\nsleep 10\n' > "$T/.play/permanent/prove.h-hang.play.sh"
suite b-decline c-fail; git -C "$T" add .play/permanent/repair.f-fix.play.sh .play/permanent/fix.g-noverb.play.sh .play/permanent/prove.h-hang.play.sh
run --play repair.f-fix
[[ "$RC" -eq 2 && "$ERR" == *"is a repair play, and this repo has no such verb"* && "$ERR" == *"fix: rhx grove.provision"* ]]
judge repairverb $? "a repair play is refused by its verb, with the bundle path as the fix"
run --play fix.g-noverb
[[ "$RC" -eq 2 && "$ERR" == *"does not name a verb this runner drives"* ]]
judge wrongverb $? "a play with no driven verb is refused, with the allowed set"
run --play prove.h-hang --within 1
[[ "$RC" -eq 2 && "$ERR" == *"🌙 prove.h-hang did not finish within 1s, so it proved no claim"* ]]
judge timeout $? "a play past its bound exits 2, never a verdict on its subject"
run --play prove.b-decline
[[ "$RC" -eq 2 && "$ERR" == *"🌙 prove.b-decline declined — its subject is absent"* && "$ERR" != *"✋ ConstraintError: prove.b-decline"* ]]
judge playdecline $? "a single play's decline exits 2 under 🌙, the mark --all gives it"
run --play prove.c-fail
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: prove.c-fail failed (exit 1)"* ]]
judge playfail $? "a single play's fail exits 1, with a qualified malfunction line"

# --list names the index, and says how many untracked plays sit beside it — never which
suite a-pass; run --list
[[ "$RC" -eq 2 && "$OUT" == *"   └─ plays (1)"$'\n'"      └─ prove.a-pass"* \
  && "$ERR" == *"✋ ConstraintError: "*" untracked .play.sh file(s) sit in that dir, unlisted"* && "$ERR" == *"      ├─ fix:"* && "$ERR" != *"e-untracked"* && "$ERR" == "   ✋"* ]]
judge list.untracked $? "--list names the tracked play in its tree, refuses the untracked ones by count without a name, and exits 2"
rm -f "$T/.play/permanent/prove.e-untracked.play.sh" "$T/.play/permanent/repair.f-fix.play.sh" \
  "$T/.play/permanent/fix.g-noverb.play.sh" "$T/.play/permanent/prove.h-hang.play.sh"
suite a-pass b-decline c-fail d-resnap; run --list
[[ "$RC" -eq 0 && "$OUT" == *"🎭 play.run --list"* && "$OUT" == *"   └─ plays (4)"* && "$OUT" == *"      ├─ prove.a-pass"* \
  && "$OUT" == *"      └─ prove.d-resnap"* && -z "$ERR" ]]
judge list $? "--list names each tracked play in a tree under its count, and exits 0"

# --list beside --all or --play is two subjects: a silent precedence would answer one, unasked
run --list --all
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: --list and --all name two subjects"* && "$OUT" != *"plays ("* ]]
judge list.all $? "--list beside --all is refused, never one of the two guessed"
run --list --play prove.a-pass
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: --list and --play name two subjects"* && "$OUT" != *"plays ("* ]]
judge list.play $? "--list beside --play is refused, never one of the two guessed"

# --help prints the usage and the options, from the header itself
run --help
[[ "$RC" -eq 0 && "$OUT" == *"usage:"* && "$OUT" == *"--resnap"* && "$OUT" == *"--all"* && "$OUT" == *"exit:"* ]]
judge help $? "--help prints the usage, every option, and the exit codes"

# no log dir can be made: a file squats on `.log`, so the suite halts before any play runs
suite a-pass; : > "$T/.log.squat"; rm -rf "$T/.log"; mv "$T/.log.squat" "$T/.log"
run --all --within 30
[[ "$RC" -eq 1 && "$ERR" == *"💥 MalfunctionError: could not create the log dir"* && "$OUT" != *"every play passed"* ]]
judge logdirfail $? "a log dir that cannot be made exits 1, and runs no play"

# a checkout with no play dir halts: an empty set would read as a pass
mkdir -p "$T/bare/skills"; git -C "$T/bare" init -q; cp "$RUNNER" "$T/bare/skills/play.run.sh"
OUT="$(env -u CI -u GROVE_RESNAP bash "$T/bare/skills/play.run.sh" --list 2>"$T/err")"; RC=$?; ERR="$(cat "$T/err")"; RUNS=$((RUNS + 1))
[[ "$RC" -eq 2 && "$ERR" == *"✋ ConstraintError: no tracked play dir at"* ]]
judge noplaydir $? "a checkout with no play dir halts, never an empty pass"

# shellcheck source=/dev/null
source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.play-run-all-reports-each-play.snap" name=transcript actual="$SNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 play.run --all reports each play, counts three ways, logs each, and exits as its header says"
else
  echo "✋ play.run --all did NOT hold its contract — read the arms above"
fi
exit "$FAILED"
