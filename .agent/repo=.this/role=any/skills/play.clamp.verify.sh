#!/usr/bin/env bash
######################################################################
# .what = prove a clamp BITES: revert the fix to HEAD, run the play (it must
#         fail a claim), restore the fix, run it again (it must pass)
#
# .why  = `rule.require.clamp-edge-cases` owes this for every defect fix — a
#         clamp that stays green with the fix reverted exercises no defect.
#         by hand it is a backup, N reverts, two runs, and N restores, and a
#         restore missed by hand leaves the fix silently gone from the tree
#
# usage:
#   rhx play.clamp.verify --play <slug> --revert <path> [--revert <path> …]
#   rhx play.clamp.verify --play prove.carried-tree-serves-reach \
#     --revert src/grove.provision/5.devtools/5.13.reach/_.sh
#
# options:
#   --play SLUG    a tracked play under `.play/permanent/` (as `play.run`)
#   --revert PATH  a tracked file whose fix to set aside; repeat per file.
#                  each must DIFFER from HEAD, else the revert proves naught
#   --within SECS  bound per run, passed to `play.run` (default 900)
#   -h, --help     show this header
#
# guarantee:
#   - every reverted file is restored on ANY exit (a trap), then compared byte
#     for byte to its backup; a mismatch is a malfunction, named per file
#   - the red run must fail a CLAIM (exit 1). a decline (exit 2) bites no defect
#   - it writes only the named files, and only to their HEAD content and back
#
# exit:
#   0 = red with the fix reverted, green with it restored
#   1 = the clamp did not bite, did not go green, or a restore failed
#   2 = a constraint: bad args, an untracked path, or a path equal to HEAD
######################################################################

set -uo pipefail

SKILLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "✋ ConstraintError: not inside a git checkout" >&2; exit 2; }

PLAY="" WITHIN=900 REVERTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --play)   shift; [[ $# -gt 0 ]] || { echo "✋ ConstraintError: --play needs a value" >&2; exit 2; }; PLAY="${1%.play.sh}" ;;
    --revert) shift; [[ $# -gt 0 ]] || { echo "✋ ConstraintError: --revert needs a value" >&2; exit 2; }; REVERTS+=("$1") ;;
    --within) shift; [[ $# -gt 0 ]] || { echo "✋ ConstraintError: --within needs a value" >&2; exit 2; }; WITHIN="$1" ;;
    --skill|--repo|--role) shift ;;
    -h|--help) sed -n '3,/^####*$/p' "${BASH_SOURCE[0]}" | sed '/^####*$/d; s/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown option '$1'" >&2
       echo "   └─ valid: --play <slug>  --revert <path> (repeat)  --within <secs>  --help" >&2
       exit 2 ;;
  esac
  shift
done

[[ -n "$PLAY" ]] || { echo "✋ ConstraintError: --play is required" >&2; exit 2; }
(( ${#REVERTS[@]} > 0 )) || { echo "✋ ConstraintError: at least one --revert is required" >&2; exit 2; }

# every path must be tracked AND carry a fix, else the red run proves naught
cd "$ROOT" || exit 2
for f in "${REVERTS[@]}"; do
  if ! git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    echo "✋ ConstraintError: '$f' is not tracked, so it has no HEAD to revert to" >&2; exit 2
  fi
  # a file staged new on this branch is tracked, and HEAD holds no copy of it: a
  #   revert would write it EMPTY, a red run that proves a parse error, not a bite
  if ! git cat-file -e "HEAD:$f" 2>/dev/null; then
    echo "✋ ConstraintError: '$f' is new on this branch, so HEAD holds no prior version to revert to" >&2
    echo "   └─ ⇒ name the file that CALLS it (that one has a HEAD), or remove the one guard line by hand" >&2; exit 2
  fi
  if git diff --quiet HEAD -- "$f"; then
    echo "✋ ConstraintError: '$f' equals HEAD — there is no fix in it to revert" >&2
    echo "   └─ ⇒ name only the files that carry the fix" >&2; exit 2
  fi
done

BAK="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a backup dir" >&2; exit 1; }
for f in "${REVERTS[@]}"; do
  mkdir -p "$BAK/$(dirname "$f")" && cp -p "$f" "$BAK/$f" \
    || { echo "💥 MalfunctionError: could not back up '$f'" >&2; rm -rf "$BAK"; exit 1; }
done

restored=0
restore() {
  (( restored )) && return 0
  local f bad=0
  for f in "${REVERTS[@]}"; do
    cp -p "$BAK/$f" "$f" && cmp -s "$BAK/$f" "$f" || { echo "💥 MalfunctionError: '$f' was NOT restored — its fix is kept at $BAK/$f" >&2; bad=1; }
  done
  restored=1
  (( bad )) || rm -rf "$BAK"
  return $bad
}
trap restore EXIT

run() { bash "$SKILLS/play.run.sh" --play "$PLAY" --within "$WITHIN" 2>&1; }
# .what = the play's own failed-claim lines, either glyph, minus play.run's own
#         verdict on the play (`<play> failed (exit N)`, `<play> declined — …`),
#         which names the run and is no claim
claims_failed() {
  grep -E '^ *(✋|💥) ' <<<"$1" | grep -vF -e "$PLAY failed (exit" -e "$PLAY declined" || true
}
# .what = the play's own tally line, whatever glyph leads it; else a count of its failed claims
tally() {
  local t; t="$(grep -oE '[0-9]+ held[^0-9]*[0-9]+ failed' <<<"$1" | tail -1)"
  [[ -n "$t" ]] && { printf '%s' "$t"; return 0; }
  printf '%s claim(s) failed' "$(claims_failed "$1" | grep -c . || true)"
}

echo "🐢 lets see if it bites"
echo ""
echo "🐚 play.clamp.verify --play $PLAY"
echo "   ├─ reverted to HEAD"
for f in "${REVERTS[@]}"; do echo "   │  ├─ $f"; done
echo "   │  └─ (${#REVERTS[@]} file(s))"

# red: with the fix gone, a claim must fail
for f in "${REVERTS[@]}"; do git show "HEAD:$f" > "$f"; done
red="$(run)"; redrc=$?
echo "   ├─ fix reverted → exit $redrc · $(tally "$red")"
# each failed claim, whichever glyph the play leads it with; a decline names its why
claims_failed "$red" | sed -E 's/^ */   │  /'
(( redrc == 2 )) && grep -F "$PLAY declined" <<<"$red" | sed -E 's/^ */   │  /'

restore || exit 1
trap - EXIT

# green: with the fix back, every claim must hold
green="$(run)"; greenrc=$?
echo "   └─ fix restored → exit $greenrc · $(tally "$green")"

if (( redrc != 1 )); then
  echo "" >&2
  echo "💥 MalfunctionError: the clamp did not bite: exit $redrc with the fix reverted, where a failed claim is exit 1" >&2
  (( redrc == 2 )) && echo "   └─ ⇒ exit 2 is a decline — the play could not run, so it proved no claim" >&2
  (( redrc == 0 )) && echo "   └─ ⇒ every claim held without the fix: rewrite the clamp to exercise the defect" >&2
  exit 1
fi
# 🛑 exit 1 alone is no bite: play.run maps a CRASH to 1 as well, and a reverted
#   file that crashes the play proves the file absent, never the defect caught
if [[ -z "$(claims_failed "$red")" ]]; then
  echo "" >&2
  echo "💥 MalfunctionError: the clamp did not bite: exit 1 with the fix reverted, and no claim failed" >&2
  echo "   └─ ⇒ the play crashed rather than caught the defect; its last lines:" >&2
  # each line is the PLAY's words, marked as such: its own glyphs are stripped, since
  #   play.run's tree depths would read as branches of ours with no trunk above them
  printf '%s\n' "$red" | tail -8 \
    | sed -E 's/^[[:space:]]+//; s/^(├─|└─|│)[[:space:]]*//; /^[[:space:]]*$/d; s/^/      ⇒ it said: /' >&2
  exit 1
fi
if (( greenrc != 0 )); then
  echo "" >&2
  echo "💥 MalfunctionError: the clamp is not green with the fix restored (exit $greenrc)" >&2
  claims_failed "$green" | sed -E '$!s/^ */   ├─ /; $s/^ */   └─ /' >&2
  exit 1
fi

echo ""
echo "🌊 righteous — red without the fix, green with it"
exit 0
