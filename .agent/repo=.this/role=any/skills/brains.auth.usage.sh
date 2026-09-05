#!/usr/bin/env bash
######################################################################
# .what = proxy to the brains.auth.usage alias from THIS worktree
#
# .why  = the alias lives in brains.auth.sh, but a human's shell may
#         have an older copy loaded. this skill sources this worktree's
#         copy and calls the function, so `rhx brains.auth.usage` always
#         runs the current code — no manual re-source needed.
#
# usage:
#   rhx brains.auth.usage [--reach <email>|@all] [--json]
#
# .note = unlocks the subscription key at each stored reach, queries the
#         claude usage endpoint, and renders the per-account budget tree.
######################################################################

set -uo pipefail

# locate + source brains.auth.sh, and strip the rhx `--skill` token into ${ARGS[@]}
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brains.auth.bootstrap.sh"

_brains_auth_usage "${ARGS[@]}"
