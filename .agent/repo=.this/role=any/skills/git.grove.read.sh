#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `git grove read` bash command
#
# .why  = a single allowlistable surface (rhx git.grove.read) so agents
#         can read a grove's duct output. near-term bridge until
#         git.grove is lifted into the supervisor role.
#
# usage:
#   rhx git.grove.read <name>
######################################################################
set -o pipefail

# load the installed aliases (defines git_alias_grove + ductwork).
# to install THIS worktree's version onto this machine, run:
#   rhx grove.provision --from tree --mode apply
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

# 🛑 the alias must dial the registry's seat before the duct is read
#   (`grove_ssh_seat_ready`, in git.grove.ssh.operations.sh)
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.ssh.operations.sh"
[[ -n "${ARGS[0]:-}" && "${ARGS[0]}" != -* ]] && { grove_ssh_seat_ready "${ARGS[0]}" || exit $?; }

git_alias_grove read "${ARGS[@]}"
