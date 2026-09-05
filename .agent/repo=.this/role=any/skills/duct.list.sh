#!/usr/bin/env bash
######################################################################
# .what = rhx dispatch to the global `duct.list` bash function
#
# .why  = a single allowlistable surface, and — above all — a FRESH shell per
#         run, so a check reads the installed code instead of the definitions
#         its own shell loaded at startup
#
# usage:
#   rhx duct.list                                every duct, from cache
#   rhx duct.list --on duct://grove-1            every duct on a grove
#   rhx duct.list --on duct:///                  every duct on THIS machine
#   rhx duct.list --on duct://grove-1/main       every role in one tree
#   rhx duct.list --on duct://grove-1/main/mechanic   one duct
#   rhx duct.list --refresh                      re-read live state first
#
# .note the address is a PREFIX — name as much of it as you know. no `*`, so
#       no quotes needed against your shell's globber
######################################################################
set -o pipefail

source "$(dirname "${BASH_SOURCE[0]}")/duct.operations.sh"

__duct_skill_load duct.list || exit 2
__duct_skill_args "$@"

duct.list "${DUCT_SKILL_ARGS[@]}"
