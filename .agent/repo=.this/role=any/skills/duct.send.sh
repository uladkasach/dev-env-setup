#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.send` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.send --on 'duct:///<tree>/<role>' --what 'npm run dev'
#   rhx duct.send --on 'duct://<grove>/<tree>/<role>' --what 'npm run dev'
#
# .note the busy guard refuses a send into a pane that already runs a job, so
#       a keystroke never lands in another job's stdin
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.send || exit 2
__duct_skill_args "$@"

duct.send "${DUCT_SKILL_ARGS[@]}"
