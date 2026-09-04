#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.refresh` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.refresh --on 'duct:///<tree>/<role>'
#   rhx duct.refresh --on 'duct://<grove>/<tree>/<role>'
#
# .note = the FREE repair. it forces every attached terminal to repaint and it
#         kills no program, so try it first whenever a duct looks wrong:
#
#           the picture is stale, the duct answers  → duct.refresh (loses none)
#           the duct will not answer at all         → duct.reboot  (kills the program)
#
#         a headless duct on a grove has no client attached, so a refresh there
#         reports "no repaint is owed" and exits 0 — that is success, not a miss
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.refresh || exit 2
__duct_skill_args "$@"

duct.refresh "${DUCT_SKILL_ARGS[@]}"
