#!/usr/bin/env bash
######################################################################
# .what = drive `play.run --all` over a temp repo of stub plays — one that
#         passes, one that declines, one that fails — and snap every answer
#
# .why  = `--all` folds many verdicts into one exit code. a fold that read a
#         decline as a pass, or a failure as a decline, would report a suite
#         green that proved naught. each fold is driven, its exit asserted,
#         and its text snapped
#
# .how  = `play.run` derives its checkout from its OWN file, never the cwd, so
#         a copy of it inside a temp git repo runs against that repo's plays
#
# guarantee:
#   - HERMETIC. it writes only inside its own mktemp dir, removed on exit
#   - the real skill's bytes run; only the plays it is shown are stubs
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$HERE/.agent/repo=.this/role=any/skills/play.run.sh"
[[ -r "$SKILL" ]] || { echo "✋ ConstraintError: the subject play.run.sh is absent from $HERE" >&2; exit 2; }

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/tmp"

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.play-run-all-reads-three-verdicts"

# one temp repo per suite shape — $1 = name · then the stub plays it tracks, as
#   `<slug>=<exit>` pairs
mkrepo() {
  local repo="$fixture/$1" pair slug code
  shift
  mkdir -p "$repo/.play/permanent" "$repo/skills"
  git -C "$repo" init -q
  cp "$SKILL" "$repo/skills/play.run.sh"
  for pair in "$@"; do
    slug="${pair%=*}"; code="${pair#*=}"
    printf '#!/usr/bin/env bash\necho "stub %s says exit %s"\nexit %s\n' "$slug" "$code" "$code" \
      > "$repo/.play/permanent/$slug.play.sh"
  done
  git -C "$repo" add -A
}
mkrepo mixed    prove.a-passes=0 prove.b-declines=2 prove.c-fails=1
mkrepo declined prove.a-passes=0 prove.b-declines=2
mkrepo green    prove.a-passes=0

# one case — $1 = label · $2 = exit wanted · $3 = repo · then the skill's args
case_run() {
  local label="$1" want="$2" repo="$fixture/$3" out rc
  shift 3
  out="$(TMPDIR="$fixture/tmp" bash "$repo/skills/play.run.sh" "$@" 2>&1)" && rc=0 || rc=$?
  # the log dir is a mktemp name; the fixture path differs per run
  out="${out//$fixture/<fixture>}"
  # each --all run names its log dir by its utc stamp and pid; one token stands for both
  out="$(sed -E 's#what=all/[0-9T:-]+Z\.pid[0-9]+#what=all/<stamp>#g' <<< "$out")"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$want" ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc, expected rc=$want"
  failed=1
  return 1
}

case_run "--all · a pass, a decline, a failure → 1"  1 mixed    --all --within 30
case_run "--all · a pass and a decline → 2"          2 declined --all --within 30
case_run "--all · every play passes → 0"             0 green    --all --within 30
case_run "--all with --play → two subjects, refused" 2 green    --all --play prove.a-passes
case_run "an unknown flag → refused, names the valid" 2 green   --every 5
case_run "--help → the usage"                        0 green    --help

# a fold that dropped a play is the defect this clamp exists for: each verdict
#   line must name its own play, in the mixed suite
for want in "✔ prove.a-passes" "🌙 prove.b-declines" "💥 prove.c-fails" "1 passed · 1 declined · 1 failed"; do
  if [[ "$transcript" == *"$want"* ]]; then
    echo "   • the mixed suite names '$want' ✔"
  else
    cry "   💥 MalfunctionError: the mixed suite never names '$want'"
    failed=1
  fi
done

# the suite's verdict lands where a ship report reads it: a summary under the repo's .log/
summaries="$(find "$fixture" -path '*/.log/role=mechanic/skill=play.run/what=all/*/summary.log' 2>/dev/null)"
if grep -qs '1 passed · 1 declined · 1 failed' $summaries; then
  echo "   • the --all verdict lands in .log/role=mechanic/skill=play.run/what=all/<stamp>/summary.log ✔"
else
  cry "   💥 MalfunctionError: no summary.log under .log/role=mechanic/skill=play.run/what=all holds the mixed verdict"
  failed=1
fi

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.play-run-all-reads-three-verdicts.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
