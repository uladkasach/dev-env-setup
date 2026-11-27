#!/usr/bin/env bash
######################################################################
# .what = ask the REAL anthropic oauth usage and profile endpoints with a token that
#         is not one, and fail unless each refusal arrives in the shape the reader maps
#
# .why  = `rhx brains.auth.test` is hermetic: every reply it reads is a fixture, so a
#         drift in the live refusal (a status moved, an error body reshaped) would pass
#         all of it while every account read rendered the wrong cause. a refusal is the
#         one live answer a test can ask for with no account at stake
#
# .the claims
#   1. the usage endpoint answers a bad bearer with http 401, and a json body whose
#      `.error.message` (or `.error`) names why
#   2. `_brains_auth_node_via_access` maps that reply to `token_expired`, with the
#      endpoint's own detail carried, and its severity is `constraint` (the caller's fix)
#   3. the profile endpoint answers the same bearer with http 401
#
# guarantee:
#   - no account is read: HOME is a temp dir, and the bearer is a literal no grant holds
#   - no token is minted or rotated: no refresh call is made
#   - declines (exit 2, named) where the endpoint is not reached (no network)
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$HERE/src/grove.provision/2.shell/2.7.aliases/brains.auth.sh"

home="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$home"' EXIT
export HOME="$home"
BAD='sk-ant-oat01-no-grant-holds-this-literal'

failed=0
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

# shellcheck source=/dev/null
source "$LIB" >/dev/null 2>&1
declare -f _brains_auth_usage_reply >/dev/null \
  || { echo "💥 MalfunctionError: $LIB defines no _brains_auth_usage_reply" >&2; exit 1; }
ua="$(_brains_auth_ua)"

echo "🌲 prove.brains-auth-endpoints-answer-live"

######################################################################
# 1. the usage endpoint, raw
######################################################################
resp="$(_brains_auth_usage_reply "$ua" "$BAD" </dev/null 2>/dev/null)"; ccode=$?
[[ "$ccode" -eq 0 ]] \
  || { echo "🌙 prove.brains-auth-endpoints-answer-live declined: curl could not reach the endpoint (rc $ccode)" >&2
       echo "   └─ run it where the box reaches api.anthropic.com" >&2; exit 2; }
code="${resp##*$'\n'}"; body="${resp%$'\n'*}"
claim "usage · a bad bearer reads http 401" test "$code" = 401
claim "usage · the body is json that names why" \
  bash -c 'jq -e "(.error.message // .error) | type == \"string\" and length > 0" <<<"$1" >/dev/null 2>&1' _ "$body"

######################################################################
# 2. the classifier over the live reply
######################################################################
node="$(_brains_auth_node_via_access "$ua" live-refusal "$BAD" </dev/null 2>/dev/null)"
err="$(jq -r '.error // empty' <<<"$node" 2>/dev/null)"
claim "usage · the classifier maps it to token_expired" test "$err" = token_expired
claim "usage · the node carries the endpoint's own detail" \
  bash -c '[[ -n "$(jq -r ".detail // empty" <<<"$1" 2>/dev/null)" ]]' _ "$node"
claim "usage · its severity is constraint: the caller's to fix" test "$(_brains_auth_severity_for_error "$err")" = constraint

######################################################################
# 3. the profile endpoint, raw
######################################################################
resp="$(_brains_auth_profile_reply "$ua" "$BAD" </dev/null 2>/dev/null)"
claim "profile · a bad bearer reads http 401" test "${resp##*$'\n'}" = 401

echo
[[ "$failed" -eq 0 ]] || { echo "💥 prove.brains-auth-endpoints-answer-live — a claim missed" >&2; exit 1; }
echo "🌲 all claims held ✔"
