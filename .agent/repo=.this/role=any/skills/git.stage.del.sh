#!/usr/bin/env bash
######################################################################
# .what = unstage paths: the index entry returns to HEAD, the worktree keeps its bytes
#
# .why  = `git.stage.add .` can sweep in a file no commit should carry (a local
#         settings file, a lock). the peer that takes one back out was absent, so
#         the only way was a raw `git restore --staged` the hooks refuse
#
# usage:
#   rhx git.stage.del <path> [<path> ...]
#
# guarantee:
#   - touches the INDEX only; the worktree file is never written
#   - every path must sit inside this repo, else it refuses before any change
#   - idempotent: a path already unstaged is a no-op
#   - exit 0 = done · 1 = git failed · 2 = bad input
######################################################################

set -uo pipefail

main() {
  local paths=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🐚 git.stage.del — unstage paths; the worktree keeps its bytes"
        echo ""
        echo "usage:"
        echo "  rhx git.stage.del <path> [<path> ...]"
        echo ""
        echo "example:"
        echo "  rhx git.stage.del .claude/settings.local.json"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) paths+=("$1"); shift ;;
    esac
  done

  if [[ "${#paths[@]}" -eq 0 ]]; then
    echo "✋ ConstraintError: name at least one path" >&2
    echo "   fix: rhx git.stage.del <path> [<path> ...]" >&2
    return 2
  fi

  local root
  if ! root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    echo "✋ ConstraintError: not inside a git checkout" >&2
    return 2
  fi

  # refuse any path outside the repo, before a single index write
  #   - lexical (-s): an index entry is named by its path in the tree, so a symlinked
  #     dir inside the repo still holds in-repo entries
  local p abs
  for p in "${paths[@]}"; do
    abs="$(realpath -m -s -- "$p")"
    if [[ "$abs" != "$root" && "$abs" != "$root"/* ]]; then
      echo "✋ ConstraintError: $p sits outside this repo" >&2
      return 2
    fi
  done

  echo "🐢 righteous"
  echo ""
  echo "🐚 git.stage.del"
  if ! git restore --staged -- "${paths[@]}"; then
    echo "   └─ 💥 MalfunctionError: git restore --staged failed; the index may be partly changed" >&2
    echo "      read why: git status" >&2
    return 1
  fi
  local i=0 n="${#paths[@]}"
  for p in "${paths[@]}"; do
    i=$((i + 1))
    if [[ "$i" -eq "$n" ]]; then echo "   └─ unstaged: $p"; continue; fi
    echo "   ├─ unstaged: $p"
  done
}

main "$@"
