#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to `git grove sync`: converge this box's forest toward the tailnet
#
# .why  = the forest is written by hand on each box, so a replaced grove leaves a dead
#         row and no live one. this registers each new hetzner grove the tailnet holds,
#         both seats, and names each dead row with its `del`
#
# usage:
#   rhx git.grove.sync                 # plan: what it would register
#   rhx git.grove.sync --mode apply    # register
######################################################################
set -o pipefail

source ~/.bash_aliases 2>/dev/null || true

if ! command -v git_alias_grove &>/dev/null; then
  echo "✋ ConstraintError: git_alias_grove not found — the installed aliases are stale" >&2
  echo "   └─ fix: rhx grove.provision --what 2.7.aliases --mode apply" >&2
  exit 2
fi

# 🛑 the installed copy runs, never this checkout's: say so when they differ
#   ⚠️ on STDOUT: rhx relays a skill's stderr only on a non-zero exit
_aliases_src="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
if [[ -f "$_aliases_src" ]] && ! cmp -s "$_aliases_src" ~/.bash_aliases; then
  echo "⚠️ ~/.bash_aliases differs from this checkout, so an older git grove runs here"
  echo "   └─ fix: rhx grove.provision --what 2.7.aliases --mode apply"
  echo ""
fi

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift; ARGS+=("$@"); break ;;
    # `shift 2` with one arg left shifts naught, so it would loop forever: take what is there
    --skill|--repo|--role) shift; [[ $# -gt 0 ]] && shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

git_alias_grove sync "${ARGS[@]}"
