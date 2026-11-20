#!/usr/bin/env bash
######################################################################
# .what = prove two refusals name their whole subject:
#         1. `aws.reach.set` reads a roles-anywhere trust refusal (source identity
#            OR session tags) and names every action the trust statement owes
#         2. `git.grove.provision test` prints the claims the ladder's halt points at
#
# .why  = both were measured on hetzner 2026-11-16. the reach fix-text read a
#         TagSession denial as "this box is not in the trust policy", and named
#         one action per denial — one infra round trip each. the smoketest
#         printed the ladder from `why:` down, so "each claim is named above"
#         pointed at an empty page
#
# guarantee:
#   - hermetic: pure functions over fixture text; no network, no aws, no grove
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}
is() { [[ "$1" == "$2" ]]; }
has() { [[ "$1" == *"$2"* ]]; }

echo "🌲 prove.gate-names-what-it-refuses"

####################################################################
# arm 1 — the trust refusal reader
####################################################################
# shellcheck source=/dev/null
source "$SKILLS/aws.reach.operations.sh"
# the reader is the shared runtime's, which the skill loads at its rung 0
aws_reach_runtime_load || { echo "✋ ConstraintError: the shared runtime did not load" >&2; exit 2; }
export -f grove_aws_trust_refused 2>/dev/null
# the negative checks below pass on an absent reader too — so the reader must exist first
check "the trust reader is declared" is "$(declare -F grove_aws_trust_refused)" grove_aws_trust_refused

deny() { printf 'An error occurred (AccessDenied): User: arn:aws:sts::<acct>:assumed-role/<role>/<session> is not authorized to perform: %s on resource: arn:aws:iam::<acct>:role/<role>' "$1"; }

check "a source-identity refusal reads as sts:SetSourceIdentity" \
  is "$(grove_aws_trust_refused "$(deny sts:SetSourceIdentity)")" sts:SetSourceIdentity
check "a session-tag refusal reads as sts:TagSession" \
  is "$(grove_aws_trust_refused "$(deny sts:TagSession)")" sts:TagSession
check "a bare AssumeRole refusal is NOT a session refusal (rc 1)" \
  bash -c '! grove_aws_trust_refused "$1" >/dev/null' _ "$(deny sts:AssumeRole)"
owed="$(grove_aws_trust_actions_owed)"
for action in sts:AssumeRole sts:SetSourceIdentity sts:TagSession; do
  check "the owed set names $action" has "$owed" "\"$action\""
done
check "aws.reach.set reads the refusal through the reader" \
  grep -q 'grove_aws_trust_refused "\$WHOAMI"' "$SKILLS/aws.reach.set.sh"
check "aws.reach.set prints the whole owed set" \
  grep -q 'grove_aws_trust_actions_owed' "$SKILLS/aws.reach.set.sh"
# a refusal that says "an infra ask" leaves the human to find which repo; both name it
check "both trust refusals name the repo to ask" \
  is "$(grep -c 'an ask of \$ORG/infrastructure' "$SKILLS/aws.reach.set.sh")" 2

####################################################################
# arm 1b — the 5.13.reach verify sorts the SAME refusals the same way:
#   a plan, and the ready.verify ladder that relays it, must name the repair
#   aws.reach.set names. a session refusal holds "AssumeRole" too, so it must
#   never fall to the bare-AssumeRole text
####################################################################
# shellcheck source=/dev/null
source "$HERE/src/grove.aws.sh"
# shellcheck source=/dev/null
source "$HERE/src/grove.provision/5.devtools/5.13.reach/_.sh"   # the shared two-cause sayer
# shellcheck source=/dev/null
source "$HERE/src/grove.provision/5.devtools/5.13.reach/configure.verify.sh"
check "the verify's refusal sayer is declared" \
  is "$(declare -F grove_provision_5_13_reach_refusal_say)" grove_provision_5_13_reach_refusal_say
transcript=""
say_refusal() {  # $1 = label, $2 = aws's words. sets $out; appends to the transcript
  out="$(grove_provision_5_13_reach_refusal_say ahbode prep '<profile>' "$2" '<role>' 2>&1)"
  transcript+="## $1"$'\n'"$out"$'\n\n'
}

say_refusal "a session-tag refusal" "$(deny sts:TagSession)"
check "verify · a session refusal names the action refused" has "$out" "refuses what its session carries (sts:TagSession)"
check "verify · it names the whole owed set" has "$out" "$(grove_aws_trust_actions_owed)"
check "verify · it is never read as a bare trust gap" bash -c '[[ "$1" != *"this box is REFUSED it"* ]]' _ "$out"

say_refusal "a source-identity refusal" "$(deny sts:SetSourceIdentity)"
check "verify · a source-identity refusal names it" has "$out" "(sts:SetSourceIdentity)"

say_refusal "a bare AssumeRole refusal" "$(deny sts:AssumeRole)"
check "verify · a bare refusal asks the ORG question first" has "$out" "does a 'ahbode' row belong on a grove of THIS org at all?"
check "verify · a bare refusal names the whole owed set too" has "$out" "$(grove_aws_trust_actions_owed)"
check "verify · a bare refusal names the repo to ask" has "$out" "an ask of ahbode/infrastructure"
check "verify · no refusal names a camp role (a hetzner box has none)" bash -c '[[ "$1" != *"CAMP role"* ]]' _ "$transcript"

say_refusal "a profile aws cannot find" "The config profile (<profile>) could not be found"
check "verify · the transcript holds all four refusals" test "$(grep -c '^## ' <<<"$transcript")" -eq 4
check "verify · an unfound profile names the re-apply" has "$out" "fix: rhx grove.provision --what 5.13.reach --mode apply"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.gate-names-what-it-refuses.snap" name=transcript actual="$transcript" || failed=1

####################################################################
# arm 2 — the smoketest prints what the ladder's halt points at
####################################################################
# shellcheck source=/dev/null
source "$SKILLS/git.grove.operations.sh"
export -f _say_ladder_claims 2>/dev/null
check "the ladder-claims reader is declared" is "$(declare -F _say_ladder_claims)" _say_ladder_claims

cat > "$fixture/box.log" <<'LOG'
🌲 git.grove.ready.verify <grove>
   └─ rungs
      ├─ 4. tree
      │  ├─ <grove>.ground — ✔ 213 · ✋ 0
      │  ├─ <grove> — ✔ 236 · ✋ 2
      │  │  ├─ ✋ ehmpathy.test — the hop is declared, and this box is REFUSED it
      │  │  └─ ✋ ehmpathy.prep — the hop is declared, and this box is REFUSED it

  why: bundle verify(s) did not hold on <grove> (2) — each claim is named above, under the seat that raised it
  fix:
    ✋ a fix-text line below why, never a claim
LOG
said="$(_say_ladder_claims "$fixture/box.log")"
check "both claims are printed" bash -c '[[ "$(grep -c "✋ ehmpathy" <<< "$1")" -eq 2 ]]' _ "$said"
check "each seat's tally is printed" has "$said" "<grove>.ground — ✔ 213 · ✋ 0"
check "the halt's own why and fix are not swept in" bash -c '! grep -q "why:\|fix-text" <<< "$1"' _ "$said"
check "an absent log prints naught, rc 0" bash -c '[[ -z "$(_say_ladder_claims /absent)" ]]'
check "provision test prints the ladder's claims" \
  grep -q '_say_ladder_claims "\$LOGDIR/box.log"' "$SKILLS/git.grove.provision.test.sh"
# the exact bytes provision test prints above its why: (it indents each line by two)
play_snap_verify dir="$HERE/.play/permanent/prove.gate-names-what-it-refuses.snap" name=ladder-claims \
  actual="$(printf '%s\n' "$said" | sed 's/^/  /')" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.gate-names-what-it-refuses: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
