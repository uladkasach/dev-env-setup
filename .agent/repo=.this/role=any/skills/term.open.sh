#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `term.open` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx term.open --via kitty                             a shell
#   rhx term.open --via kitty --cwd <path>                a shell, at a path
#   rhx term.open --via kitty --on <terminal>             attach a LOCAL duct
#   rhx term.open --via kitty --on <user@host:session>    attach a REMOTE duct
#   rhx term.open --via kitty --on <terminal> --for <role>  a role tab
#
# ⚠️ `--on` here names a TERMINAL, never a duct URI. ductwork's `--on` takes
#   `duct://<host>/<tree>/<role>`; the two vocabularies are not interchangeable
#
# ⚠️ a REMOTE attach wants the duct to exist first —
#     rhx duct.open --on 'duct://<grove>/<tree>/<role>'
#     rhx term.open --via kitty --on '<seat>:<tree>/<role>'
#
# .note this OPENS A WINDOW on the human's desktop, so it declines on any box
#       with no display. an agent reaches a duct through send + read instead
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/term.operations.sh"

__term_skill_load term.open || exit 2
__term_skill_args "$@"

term.open "${TERM_SKILL_ARGS[@]}"
