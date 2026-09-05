#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `git grove get` bash command
#
# .why  = a single allowlistable surface (rhx git.grove.get) so agents
#         can show one grove. near-term bridge until git.grove is lifted
#         into the supervisor role.
#
# usage:
#   rhx git.grove.get <name>
######################################################################
set -uo pipefail

source ~/.bash_aliases 2>/dev/null || true

if ! command -v git_alias_grove &>/dev/null; then
  echo "✋ git_alias_grove not found — the installed aliases are stale" >&2
  echo "   └─ fix: install them —" >&2
  echo "        rhx grove.provision --from main --mode apply" >&2
  exit 2
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

git_alias_grove get "${ARGS[@]}"
