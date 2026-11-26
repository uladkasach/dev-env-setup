#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `term.vars` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx term.vars --via kitty --on <terminal>   every window's kitty user vars
#   rhx term.vars --via kitty --pid <pid>       by pid
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/term.operations.sh"

__term_skill_load term.vars || exit 2
__term_skill_args "$@"

term.vars "${TERM_SKILL_ARGS[@]}"
