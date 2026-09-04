#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.stop` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.stop --on 'duct:///<tree>/<role>'
#   rhx duct.stop --on 'duct://<grove>/<tree>/<role>'
#
# .note a stop KILLS the session and every job in it. the work is gone; only
#       the tree on disk survives
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.stop || exit 2
__duct_skill_args "$@"

duct.stop "${DUCT_SKILL_ARGS[@]}"
