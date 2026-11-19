#!/usr/bin/env bash
######################################################################
# .what = drive `play.clamp.verify` over a temp repo of stub plays — every
#         refusal, a clamp that bites, and the three that do not — and snap
#         every answer a human reads
#
# .why  = the skill folds two runs into one verdict. a fold that read a decline
#         as a bite, or a clamp green both ways as proof, would certify a test
#         that exercises no defect. each verdict is driven, its exit asserted,
#         its restore checked, and its text snapped
#
# .how  = `play.clamp.verify` and `play.run` both derive their checkout from
#         their OWN file, so copies inside a temp git repo run against that
#         repo's plays and files
#
# guarantee:
#   - HERMETIC. it writes only inside its own mktemp dir, removed on exit
#   - the real skills' bytes run; only the plays they are shown are stubs
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"
for f in play.clamp.verify.sh play.run.sh; do
  [[ -r "$SKILLS/$f" ]] || { echo "✋ ConstraintError: the subject $f is absent from $SKILLS" >&2; exit 2; }
done

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/tmp" "$fixture/nowhere"

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.clamp-verify-names-each-verdict"

####################################################################
# the fixture repo: HEAD holds the defect, the work tree holds the fix
####################################################################
repo="$fixture/repo"
mkdir -p "$repo/.play/permanent" "$repo/skills"
git -C "$repo" init -q
cp "$SKILLS/play.clamp.verify.sh" "$SKILLS/play.run.sh" "$repo/skills/"

# .what = one stub play — $1 = slug · $2 = its body
stub() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$repo/.play/permanent/$1.play.sh"; }
stub prove.subject-is-fixed 'd="$(cd "$(dirname "$0")/../.." && pwd)"
grep -qx fixed "$d/subject.txt" || { echo "   ✋ subject.txt is not fixed"; exit 1; }
echo "   • subject.txt is fixed ✔"; exit 0'
stub prove.always-holds   'echo "   • naught to fail ✔"; exit 0'
stub prove.always-declines 'echo "   🌙 this box cannot run it"; exit 2'
stub prove.always-fails   'echo "   💥 MalfunctionError: a claim the fix does not touch"; exit 1'
# a play that CRASHES without the fix: exit 1, and no claim ever failed
stub prove.crashes-on-revert 'd="$(cd "$(dirname "$0")/../.." && pwd)"
grep -qx fixed "$d/subject.txt" || { echo "line 3: an_absent_function: command not found" >&2; exit 1; }
echo "   • subject.txt is fixed ✔"; exit 0'

printf 'broken\n' > "$repo/subject.txt"
printf 'a\n' > "$repo/other.txt"
printf 'unchanged\n' > "$repo/still.txt"
git -C "$repo" add -A
git -C "$repo" -c user.email=fixture@example.com -c user.name=fixture commit -qm 'fixture: the defect' \
  || { echo "💥 MalfunctionError: could not commit the fixture repo" >&2; exit 1; }
printf 'fixed\n' > "$repo/subject.txt"
printf 'b\n' > "$repo/other.txt"
printf 'new\n' > "$repo/untracked.txt"
printf 'staged new\n' > "$repo/stagednew.txt"
git -C "$repo" add stagednew.txt

# one case — $1 = label · $2 = exit wanted · $3 = cwd · then the skill's args
case_run() {
  local label="$1" want="$2" cwd="$3" out rc
  shift 3
  out="$(cd "$cwd" && TMPDIR="$fixture/tmp" bash "$repo/skills/play.clamp.verify.sh" "$@" 2>&1)" && rc=0 || rc=$?
  out="${out//$fixture/<fixture>}"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$want" ]]; then
    echo "   • $label → rc=$rc ✔"
  else
    cry "   💥 MalfunctionError: $label → rc=$rc, expected rc=$want"
    failed=1
  fi
}

# .what = after every run, the work tree must still hold the fix
fix_kept() {
  if [[ "$(cat "$repo/subject.txt")" == fixed && "$(cat "$repo/other.txt")" == b ]]; then
    echo "   • $1 · the fix is restored ✔"
  else
    cry "   💥 MalfunctionError: $1 · the work tree lost its fix"
    failed=1
  fi
}

####################################################################
# the refusals — each before a single file is touched
####################################################################
case_run "--help → the usage"                              0 "$repo" --help
case_run "an unknown option → refused, names the valid"   2 "$repo" --every 5
case_run "no --play → refused"                             2 "$repo" --revert subject.txt
case_run "no --revert → refused"                           2 "$repo" --play prove.subject-is-fixed
case_run "an untracked path → refused"                     2 "$repo" --play prove.subject-is-fixed --revert untracked.txt
case_run "a path equal to HEAD → refused"                  2 "$repo" --play prove.subject-is-fixed --revert still.txt
case_run "a path staged new, absent from HEAD → refused"   2 "$repo" --play prove.subject-is-fixed --revert stagednew.txt
if [[ "$(cat "$repo/stagednew.txt")" == "staged new" ]]; then
  echo "   • a staged-new path · left intact, never emptied ✔"
else
  cry "   💥 MalfunctionError: a staged-new path · the refusal emptied it"; failed=1
fi
case_run "outside a git checkout → refused"                2 "$fixture/nowhere" --play prove.subject-is-fixed --revert subject.txt

####################################################################
# the verdicts — a bite, and the three shapes that are not one
####################################################################
case_run "a clamp that bites → red, then green"            0 "$repo" --play prove.subject-is-fixed --revert subject.txt --within 30
fix_kept "a bite"
case_run "a clamp green both ways → did not bite"          1 "$repo" --play prove.always-holds --revert other.txt --within 30
fix_kept "no bite"
case_run "a play that declines → a decline, never a bite"  1 "$repo" --play prove.always-declines --revert other.txt --within 30
fix_kept "a decline"
case_run "a clamp red both ways → not green"               1 "$repo" --play prove.always-fails --revert other.txt --within 30
fix_kept "never green"
case_run "a play that crashes on revert → no bite"         1 "$repo" --play prove.crashes-on-revert --revert subject.txt --within 30
fix_kept "a crash"
if [[ "$transcript" == *"exit 1 with the fix reverted, and no claim failed"* ]]; then
  echo "   • a crash · named as no claim failed ✔"
else
  cry "   💥 MalfunctionError: a crash · not named as a crash"; failed=1
fi

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.clamp-verify-names-each-verdict.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
