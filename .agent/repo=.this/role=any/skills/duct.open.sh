#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.open` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.open --on 'duct:///<tree>/<role>'                  local, headless
#   rhx duct.open --on 'duct://<grove>/<tree>/<role>'           remote, headless
#   rhx duct.open --on 'duct:///<tree>/<role>' --mode headfull  attach
#
# .note headfull attaches an interactive tmux client, so it wants a terminal;
#       an agent reaches a duct through send + read, never an attach
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.open || exit 2
__duct_skill_args "$@"

duct.open "${DUCT_SKILL_ARGS[@]}"
