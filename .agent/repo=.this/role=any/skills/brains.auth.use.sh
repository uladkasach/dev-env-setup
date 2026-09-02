#!/usr/bin/env bash
######################################################################
# .what = proxy to the brains.auth.use alias from THIS worktree
#
# .why  = the same freshness guarantee its two siblings have — and `use`
#         needs it MOST, which is why its absence was a safety inversion
#         rather than a cosmetic gap.
#
#         the proxies exist because a human's shell may hold an older
#         copy of the alias. for `usage` a stale copy renders stale
#         numbers. for `use` a stale copy MUTATES CREDENTIALS with
#         whatever logic it was loaded with — a shell that predates the
#         compare-and-swap guard will happily install over an account
#         that arrived mid-flight and destroy its only live token.
#         so the riskiest command was the one command with no way to
#         guarantee you were running the current version of it.
#
# usage:
#   rhx brains.auth.use [--reach <email>]
#
# .note = this is deliberately NOT an automation surface, and adding it
#         does not create one. the vision withholds a `--json` contract
#         from `use` because a machine-readable credential swap invites
#         an unattended caller to drive it; that argument is about the
#         OUTPUT contract and it holds. this file adds no output
#         contract — it is the same interactive command, reachable the
#         same way every other command in this repo is (`rhx <name>`).
#         a human who learned `rhx brains.auth.usage` should not find
#         that the one command which touches their credentials answers
#         differently.
######################################################################

set -uo pipefail

# locate + source src/brains.auth.sh, and strip the rhx `--skill` token into ${ARGS[@]}
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brains.auth.bootstrap.sh"

_brains_auth_use "${ARGS[@]}"
