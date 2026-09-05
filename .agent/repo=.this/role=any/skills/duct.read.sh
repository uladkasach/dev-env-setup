#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.read` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.read --on 'duct:///<tree>/<role>'
#   rhx duct.read --on 'duct://<grove>/<tree>/<role>' --lines 100
#
# .note a read peeks at the scrollback; it never attaches, so it is safe to
#       run against a duct a human already watches
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.read || exit 2
__duct_skill_args "$@"

duct.read "${DUCT_SKILL_ARGS[@]}"
