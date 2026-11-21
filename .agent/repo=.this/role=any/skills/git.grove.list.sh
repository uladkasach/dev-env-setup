#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `git grove list` bash command
#
# .why  = a single allowlistable surface (rhx git.grove.list) so agents
#         can list registered groves. near-term bridge until git.grove
#         is lifted into the supervisor role.
#
# usage:
#   rhx git.grove.list
######################################################################
set -o pipefail

# load the installed aliases (defines git_alias_grove + ductwork).
# to install THIS worktree's version onto this machine, run:
#   rhx grove.provision --from tree --mode apply
source ~/.bash_aliases 2>/dev/null || true

if ! command -v git_alias_grove &>/dev/null; then
  echo "✋ ConstraintError: git_alias_grove not found — the installed aliases are stale" >&2
  echo "   └─ fix: install them —" >&2
  echo "        rhx grove.provision --from main --mode apply" >&2
  exit 2
fi

# 🛑 the installed copy runs, never this checkout's: say so when they differ
#   📜 2026-11-20: a box ran pre-#203 aliases for a day, so every grove read was the
#   old code's, and no line said so
_aliases_src="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
#   ⚠️ on STDOUT: rhx relays a skill's stderr only on a non-zero exit, and a list exits 0
if [[ -f "$_aliases_src" ]] && ! cmp -s "$_aliases_src" ~/.bash_aliases; then
  echo "⚠️ ~/.bash_aliases differs from this checkout, so an older git grove runs here"
  echo "   └─ fix: rhx grove.provision --what 2.7.aliases --mode apply"
  echo ""
fi

# rhachet forwards its own --skill/--repo/--role flags; drop them.
# a bare `--` ends the strip — every arg after it is literal, so a value that
# looks like a flag (e.g. a grove literally named `--skill`) still reaches through.
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --) shift; ARGS+=("$@"); break ;;
    --skill|--repo|--role) shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

git_alias_grove list "${ARGS[@]}"
