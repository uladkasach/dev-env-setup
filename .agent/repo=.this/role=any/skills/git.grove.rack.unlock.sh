#!/usr/bin/env bash
######################################################################
# .what = unlock this laptop's rack for ONE org's env, whatever org the
#         checkout you stand in declares
#
# .why  🛑 `rhx keyrack unlock` is CHECKOUT-SCOPED, and it refuses a foreign org
#
#   measured 2026-09-28 from the ahbode checkout:
#
#     rhx keyrack unlock --owner ehmpath --env camp --key AWS_PROFILE --org aether
#       → ✋ key excluded by --org filter: AWS_PROFILE
#          ├─ orgsHeld: ahbode
#          └─ hint: re-run without --org, or with --org ahbode
#
#   ⚠️ and BOTH halves of that hint are traps:
#     · "without --org" unlocks ahbode's camp profile — a different account
#     · "--org ahbode" does the same, and says so out loud
#   ⇒ each reads as a pass and leaves the slug you asked for locked
#
# .why a SKILL and not a line in a howto
#   the reachable form is `env -C <gitroot> rhx keyrack unlock …`, and that is
#   the kind of incantation `rule.forbid.adhoc-shell` exists to retire: an absent
#   skill IS the defect. so `git.grove.wake`'s halt names THIS, and a human types
#   one command rather than a path plus an env prefix
#
# .how  a scratch git root with a one-org manifest (`term=keyrack.gitroot`) — the
#       same pattern five bundles in this repo already carry, held once in
#       `git.grove.rack.operations`
#
# usage:
#   rhx git.grove.rack.unlock --org aether --env camp
#   rhx git.grove.rack.unlock --org aether --env camp --key AWS_PROFILE
#
# options:
#   --org   the org whose slugs to unlock (required)
#   --env   the env to unlock (required)
#   --key   narrow to one key; default = every key the manifest declares
#
# 🛑 this is a LAPTOP verb, and never a provision step
#   an unlock may open a browser for an SSO login, so it is a tty flow — and a
#   tty on the provision path is a declared blocker
#   (`rule.require.one-command-provision`). a human runs this at a keyboard;
#   no bundle and no duct send ever does
#
# guarantee:
#   - it relays keyrack's own stdout + stderr, unswallowed
#   - it writes ONE file: the scratch manifest, which holds NAMES only
#   - exit 0 = keyrack unlocked · 2 = a bad ask, or keyrack refused
######################################################################
set -uo pipefail

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.rack.operations.sh"

ORG=""
ENV=""
KEY=""

# ⚠️ rhachet injects `--skill <slug>` ahead of a caller's own flags, so an arg
#    loop that does not absorb it halts on a flag the caller never typed
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role) shift 2 ;;
    --org) ORG="${2:-}"; shift 2 ;;
    --env) ENV="${2:-}"; shift 2 ;;
    --key) KEY="${2:-}"; shift 2 ;;
    -h|--help)
      echo "🔐 git.grove.rack.unlock — unlock one org's env on this laptop"
      echo ""
      echo "  usage:"
      echo "    rhx git.grove.rack.unlock --org <org> --env <env> [--key <key>]"
      echo ""
      echo "  inputs:"
      echo "    --org   the org whose slugs to unlock          (required)"
      echo "    --env   the env to unlock                      (required)"
      echo "    --key   narrow to one key                      (default: all)"
      echo ""
      echo "  example:"
      echo "    rhx git.grove.rack.unlock --org aether --env camp --key AWS_PROFILE"
      echo ""
      echo "  why it exists: 'rhx keyrack unlock' reads the org off the CHECKOUT,"
      echo "  so it refuses any org but this tree's — and its own hint unlocks"
      echo "  another account's profile while it looks like a pass."
      exit 0
      ;;
    *)
      echo "✋ unknown flag: $1" >&2
      echo "   read what it takes: rhx git.grove.rack.unlock --help" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ORG" || -z "$ENV" ]]; then
  echo "✋ --org and --env are both required" >&2
  echo "   e.g. rhx git.grove.rack.unlock --org aether --env camp" >&2
  echo "   read the orgs the rack holds: rhx keyrack list --owner ehmpath" >&2
  exit 2
fi

echo "🔐 git.grove.rack.unlock --org $ORG --env $ENV${KEY:+ --key $KEY}"

# ⚠️ a NATIVE org needs no scratch root — the plain unlock reaches it, and one
#    fewer file written is one fewer fact to explain when a read answers empty
if _rack_org_is_native "$ORG"; then
  echo "   ├─ '$ORG' is this checkout's own org — the plain unlock reaches it"
  echo ""
  rhx keyrack unlock --owner ehmpath --env "$ENV" ${KEY:+--key "$KEY"}
  exit $?
fi

echo "   ├─ '$ORG' is NOT this checkout's org — routed through the scratch gitroot"
echo "   │  └─ \$HOME/$GROVE_RACK_GITROOT_REL  (term=keyrack.gitroot)"
echo ""
_rack_unlock "$ORG" "$ENV" "$KEY"
