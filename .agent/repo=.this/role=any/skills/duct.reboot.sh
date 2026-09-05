#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.reboot` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.reboot --on 'duct:///<tree>/<role>'
#   rhx duct.reboot --on 'duct://<grove>/<tree>/<role>'
#
# .note = THIS IS THE ANSWER TO A STUCK DUCT. when `duct.send` refuses because a
#         program holds the pane and that program will never finish, reboot it.
#         the session, its name, its scrollback, and its cwd all survive; only
#         the wedged program dies.
#
#         reach for `rhx duct.refresh` first if the duct still ANSWERS and only
#         the picture is wrong — that one loses no work at all.
#
#         never reach for raw `ssh <grove> "…"` because a duct is busy. that is
#         the exact trade `rule.require.reach-a-grove-through-its-duct` forbids,
#         and this verb exists so the trade is never needed
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.reboot || exit 2
__duct_skill_args "$@"

duct.reboot "${DUCT_SKILL_ARGS[@]}"
