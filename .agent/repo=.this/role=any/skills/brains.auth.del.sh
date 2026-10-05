#!/usr/bin/env bash
######################################################################
# .what = proxy to the brains.auth.del alias from THIS worktree
#
# .why  = the same freshness guarantee its siblings have: a shell may
#         hold an older copy of the alias, and del mutates credentials
#
# usage:
#   rhx brains.auth.del --reach <email>                # plan (preview)
#   rhx brains.auth.del --reach <email> --mode apply   # drop it
######################################################################

set -uo pipefail

# locate + source brains.auth.sh, and strip the rhx `--skill` token into ${ARGS[@]}
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brains.auth.bootstrap.sh"

_brains_auth_del "${ARGS[@]}"
