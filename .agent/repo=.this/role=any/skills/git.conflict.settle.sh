#!/usr/bin/env bash
######################################################################
# .what = settle a conflicted file mid-rebase or mid-merge, one SIDE per
#         conflicted chunk, while every chunk that merged clean stays merged
#
# .why  = a whole-file take (`git checkout --ours`, `rebase take`) drops the
#         clean half of the merge too: a file where two sides trimmed one header
#         and one side also changed code keeps the header pick and loses the code.
#         `git merge-file --ours|--theirs` over the three index stages picks a
#         side for the conflicted chunks only
#
# usage:
#   rhx git.conflict.settle --side ours   <file> [<file>...]
#   rhx git.conflict.settle --side theirs <file> [<file>...]
#
# .note = in a REBASE, `ours` is the branch under the rebase (upstream, plus
#         each commit already replayed), and `theirs` is the commit replayed now
#
# guarantee:
#   - acts only on a path that is UNMERGED in the index; any other path halts
#   - writes the file on disk only; it never stages (review, then git.stage.add)
#   - a file with no base stage (both sides added it) halts, never guesses
######################################################################

set -uo pipefail

__help() {
  cat <<'HELP'
🔀 git.conflict.settle — pick one side per conflicted chunk; clean merges stay

  usage:
    rhx git.conflict.settle --side ours|theirs <file> [<file>...]

  in a rebase: ours = upstream + commits replayed so far · theirs = the commit replayed now
  next: review the diff, then rhx git.stage.add <file>
HELP
}

main() {
  local side="" files=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) __help; return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      --side) side="${2:-}"; shift 2 ;;
      -*) echo "✋ ConstraintError: unknown flag: $1" >&2; echo "   fix: rhx git.conflict.settle --help" >&2; return 2 ;;
      *) files+=("$1"); shift ;;
    esac
  done

  # the side and at least one file are owed
  [[ "$side" == ours || "$side" == theirs ]] || {
    echo "✋ ConstraintError: --side must be ours or theirs" >&2; echo "   fix: rhx git.conflict.settle --help" >&2; return 2; }
  [[ "${#files[@]}" -gt 0 ]] || {
    echo "✋ ConstraintError: name at least one conflicted file" >&2; return 2; }

  local root; root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "✋ ConstraintError: not inside a git checkout" >&2; return 2; }
  cd "$root" || return 1

  local tmp; tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  echo "🔀 git.conflict.settle --side $side"
  local f n=0 total="${#files[@]}" rc
  for f in "${files[@]}"; do
    n=$(( n + 1 ))
    local glyph="├─"; [[ "$n" -eq "$total" ]] && glyph="└─"

    # only an unmerged path holds the three stages this reads
    [[ -n "$(git ls-files -u -- "$f")" ]] || {
      echo "   $glyph ✋ $f — not unmerged in the index; naught to settle" >&2; return 2; }
    git show ":1:$f" >"$tmp/base" 2>/dev/null || {
      echo "   $glyph ✋ $f — no base stage (both sides added it); settle it by hand" >&2; return 2; }
    git show ":2:$f" >"$tmp/ours" 2>/dev/null || { echo "   $glyph ✋ $f — no ours stage" >&2; return 2; }
    git show ":3:$f" >"$tmp/theirs" 2>/dev/null || { echo "   $glyph ✋ $f — no theirs stage" >&2; return 2; }

    # merge-file exits with the count of conflicts left (zero under a side flag); >127 is a fault
    rc=0
    git merge-file "--$side" -p "$tmp/ours" "$tmp/base" "$tmp/theirs" >"$tmp/out" || rc=$?
    [[ "$rc" -lt 128 ]] || { echo "   $glyph 💥 MalfunctionError: $f — merge-file failed (exit $rc)" >&2; return 1; }
    cat "$tmp/out" >"$f"
    echo "   $glyph ✔ $f"
  done
  echo ""
  echo "next: review the diff, then rhx git.stage.add <file>"
}

main "$@"
