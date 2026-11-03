#!/usr/bin/env bash
######################################################################
# .what = point a branch at a fresh origin/main, and carry the STAGED
#         changes onto it
#
# .why  = after a squash merge, the old branch still holds its pre-squash
#         commits. a new branch cut from it inherits them, and
#         `git.commit.set` then reads them as this branch's own work
#         (it demands a `cont:` prefix for work that already shipped).
#         the right base is origin/main, and the staged work must ride along
#
# usage:
#   rhx git.branch.set --name vlad/fix-x                 # plan (default)
#   rhx git.branch.set --name vlad/fix-x --mode apply    # apply
#
# guarantee:
#   - carries the INDEX only; refuses if the tree holds unstaged edits to
#     a tracked file (they would be left behind or clobbered)
#   - a conflict on the carry is reported, never settled for you; the
#     stash entry is kept, so no change is lost
#   - plan mode fetches and reports; it moves no ref
#   - exit 0 = done · 1 = malfunction · 2 = constraint
######################################################################
set -euo pipefail

name="" mode="plan"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) name="${2:-}"; shift 2 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

# reject absent or malformed input
[[ -n "$name" ]] || { echo "✋ ConstraintError: --name is required" >&2; exit 2; }
[[ "$mode" == plan || "$mode" == apply ]] || { echo "✋ ConstraintError: --mode is plan or apply" >&2; exit 2; }
git check-ref-format --branch "$name" >/dev/null || { echo "✋ ConstraintError: '$name' is not a valid branch name" >&2; exit 2; }
[[ "$name" != main && "$name" != master ]] || { echo "✋ ConstraintError: refuse to re-point $name" >&2; exit 2; }

# refuse unstaged edits — only the index is carried
if ! git diff --quiet; then
  echo "✋ ConstraintError: the tree holds unstaged edits to tracked files" >&2
  git diff --name-only | sed 's/^/   ├─ /' >&2
  echo "   └─ stage them (rhx git.stage.add …) or discard them, then retry" >&2
  exit 2
fi

# fetch the true base
git fetch --quiet origin main || { echo "💥 MalfunctionError: git fetch origin main failed" >&2; exit 1; }
staged="$(git diff --cached --name-only)"
count="$(printf '%s' "$staged" | grep -c . || true)"

echo "🐢 heres the wave..."
echo ""
echo "🐚 git.branch.set --name $name --mode $mode"
echo "   ├─ from:   $(git branch --show-current) @ $(git rev-parse --short HEAD)"
echo "   ├─ onto:   origin/main @ $(git rev-parse --short origin/main)"
echo "   └─ carry:  $count staged file(s)"

[[ "$mode" == apply ]] || { echo ""; echo "🥥 run with --mode apply to move the branch"; exit 0; }

# park the staged work, re-point, restore it with its index state
stashed=false
if [[ "$count" -gt 0 ]]; then
  git stash push --staged --quiet -m "git.branch.set → $name" || { echo "💥 MalfunctionError: stash failed" >&2; exit 1; }
  stashed=true
fi
git switch --quiet -C "$name" origin/main || { echo "💥 MalfunctionError: switch failed; staged work is in 'git stash list'" >&2; exit 1; }
# ⚠️ `pop --index` refuses OUTRIGHT when the index cannot be rebuilt on the new base,
#    and applies naught — measured 2026-11-03, a file origin/main had reworked left a
#    clean tree and every change parked in the stash. so fall back to a plain pop,
#    which three-way merges into the tree; only the staged-vs-unstaged split is lost
if [[ "$stashed" == true ]] && ! git stash pop --index --quiet; then
  echo "   🌙 the index could not be rebuilt on origin/main; a three-way merge into the tree instead"
  if ! git stash pop --quiet; then
    echo "✋ ConstraintError: the carry conflicts with origin/main" >&2
    git diff --name-only --diff-filter=U | sed 's/^/   ├─ conflicted: /' >&2
    echo "   ├─ fix each conflicted file, then stage it" >&2
    echo "   └─ the stash entry is KEPT until you drop it: git stash list" >&2
    exit 2
  fi
  echo "   🌙 the carried files are now UNSTAGED — stage them again before a commit"
fi

echo ""
echo "🐢 righteous! on $name @ $(git rev-parse --short HEAD), $count staged file(s) carried"
