#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `term.read` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx term.read --via kitty --on <terminal>              the base tab
#   rhx term.read --via kitty --on <terminal> --for <role> one role tab
#   rhx term.read --via kitty --pid <pid>                  by pid
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/term.operations.sh"

__term_skill_load term.read || exit 2
__term_skill_args "$@"

term.read "${TERM_SKILL_ARGS[@]}"
