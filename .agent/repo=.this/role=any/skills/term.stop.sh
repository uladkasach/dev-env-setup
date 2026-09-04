#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `term.stop` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx term.stop --via kitty --on <terminal>              close it + its tabs
#   rhx term.stop --via kitty --on <terminal> --for <role> close ONE role tab
#   rhx term.stop --via kitty --pid <pid>                  close by pid
#
# ⚠️ it closes a WINDOW, never the duct behind it. a remote tmux session
#   outlives the window that attached it — `rhx duct.stop` is what ends one
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/term.operations.sh"

__term_skill_load term.stop || exit 2
__term_skill_args "$@"

term.stop "${TERM_SKILL_ARGS[@]}"
