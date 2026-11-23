#!/usr/bin/env bash
######################################################################
# .what = prove 5.26.commitorgs's token read against the real github api:
#         the response carries the fields its filter reads, and the bundle's
#         read agrees with a second read of the same live answer
#
# .why  = the meter clamp serves `gh api user/repos` from a fixture, so it grades
#         the filter, never github's shape. a rename of `owner.type` or
#         `permissions.push` would leave that fixture green while every grove
#         derived the wrong orgs (`rule.require.external-contract-integration-tests`)
#
# .what it does to the box
#   - reads only: two `gh api` calls with this box's own gh login. no write
#
# usage:
#   rhx play.run --play prove.commitorgs-token-read-meets-real-github
#
# exit:
#   0 = every claim held · 1 = a claim failed
#   2 = declined: gh holds no USER token here (none, or a ci installation token,
#       which cannot call `user/repos`) — named, never a pass
######################################################################

set -uo pipefail

echo "🔎 prove.commitorgs-token-read-meets-real-github"
echo "   └─ subject: grove_provision_5_26_commitorgs_token_orgs, against api.github.com"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
BUNDLE="$ROOT/src/grove.provision/5.devtools/5.26.commitorgs"
[[ -f "$BUNDLE/_.sh" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $BUNDLE" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "   └─ 🌙 declined: gh is absent on this box, so no real read can run" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "   └─ 🌙 declined: jq is absent on this box" >&2; exit 2; }
if ! timeout -k 5 30 gh api user --jq '.login' </dev/null >/dev/null 2>&1; then
  echo "   └─ 🌙 declined: gh holds no user token here, so 'user/repos' cannot answer" >&2
  echo "      ⇒ run it where a user token lives: a laptop's gh login, or a cloud grove's crew seat" >&2
  exit 2
fi

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}

# row 1 — the live shape carries every field the bundle's filter reads
shape="$(timeout -k 5 60 gh api --method GET 'user/repos?per_page=20' \
  --jq 'length > 0 and (map((.owner | has("login") and has("type")) and (.permissions | has("push"))) | all)' \
  </dev/null 2>&1)"
claim "1.  user/repos answers a non-empty list, each repo with owner.login, owner.type, permissions.push" [ "$shape" == "true" ] \
  || echo "      got: $shape" >&2

# row 2 — the bundle's own read, on the live api, through its own bound and paginate
ours="$( ( # shellcheck disable=SC1091
           source "$ROOT/src/grove.org.sh"
           # shellcheck disable=SC1090
           source "$BUNDLE/_.sh"
           grove_provision_5_26_commitorgs_token_orgs; echo " rc=$?" ) )"
claim "2a. the bundle's read answers rc=0 on the real api" bash -c '[[ "$1" == *" rc=0" ]]' _ "$ours"
claim "2b. each org it names is a bare keyrack word" bash -c 'for w in ${1% rc=*}; do [[ "$w" =~ ^[a-z0-9-]+$ ]] || exit 1; done' _ "$ours"

# row 3 — a second read of the same live answer, with a filter of another form, agrees
theirs="$( ( # shellcheck disable=SC1091
             source "$ROOT/src/grove.org.sh"
             for o in $(timeout -k 5 60 gh api --paginate 'user/repos?per_page=100' \
                 --jq 'map(select(.owner.type == "Organization")) | map(select(.permissions.push)) | map(.owner.login) | .[]' \
                 </dev/null 2>/dev/null | sort -u); do
               grove_org_clonedir "$o"; echo
             done | sort -u | tr '\n' ' ' | sed 's/ *$//' ) )"
claim "3.  a second read of the live answer names the same orgs" [ "${ours% rc=*}" == "$theirs" ]

# row 4 — a real 401: a token github refuses must read as a failed read, never as 'no org'
bad="$( ( export GH_TOKEN=gho_not_a_real_token_for_this_play
          # shellcheck disable=SC1091
          source "$ROOT/src/grove.org.sh"
          # shellcheck disable=SC1090
          source "$BUNDLE/_.sh"
          grove_provision_5_26_commitorgs_token_orgs; echo " rc=$?" ) )"
claim "4.  a token github refuses (a live 401): rc=1, no orgs named" [ "$bad" == " rc=1" ]

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
