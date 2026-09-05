#!/usr/bin/env bash
######################################################################
# .what = proxy to the brains.auth.set alias from THIS worktree
#
# .why  = the alias lives in brains.auth.sh, but a human's shell may
#         have an older copy loaded. this skill sources this worktree's
#         copy and calls the function, so `rhx brains.auth.set` always
#         runs the current code — no manual re-source needed.
#
# usage:
#   rhx brains.auth.set [--reach <email>]
#
# .note = opens an isolated claude sign-in (your global login is untouched),
#         reads that session's oauth refresh token, asks the token which
#         account it is for, and stores it in the global keyrack cut at
#         that account's email — so no name has to be invented.
######################################################################

set -uo pipefail

# locate + source brains.auth.sh, and strip the rhx `--skill` token into ${ARGS[@]}
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brains.auth.bootstrap.sh"

_brains_auth_set "${ARGS[@]}"
