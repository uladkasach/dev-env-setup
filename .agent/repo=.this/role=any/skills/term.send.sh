#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `term.send` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx term.send --via kitty --on <terminal> --what '<cmd>'
#   rhx term.send --via kitty --on <terminal> --for <role> --what '<cmd>'
#   rhx term.send --via kitty --pid <pid> --what '<cmd>'
#
# ⚠️ this types into a window a HUMAN watches. to drive a duct unattended,
#   reach for `rhx duct.send` — that one needs no window at all
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/term.operations.sh"

__term_skill_load term.send || exit 2
__term_skill_args "$@"

term.send "${TERM_SKILL_ARGS[@]}"
