#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `term.list` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx term.list --via kitty          every terminal this registry knows
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/term.operations.sh"

__term_skill_load term.list || exit 2
__term_skill_args "$@"

term.list "${TERM_SKILL_ARGS[@]}"
