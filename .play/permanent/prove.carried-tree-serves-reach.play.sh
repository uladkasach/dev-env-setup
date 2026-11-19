#!/usr/bin/env bash
######################################################################
# .what = prove a declaration tree CARRIED to a box (no `.git`) serves
#         `5.13.reach`, and later yields to a real clone in `5.10.repos`
#
# .why  = a box with no github read credential (a hetzner grove) gets the
#         infra tree only by `git.grove.push`, which never sends `.git`.
#         `5.13.reach` read that tree as `absent` and said "not cloned, run
#         5.10.repos" — the wrong cause and a fix that cannot run there. and
#         once a read credential lands, `gh repo clone` refuses the non-empty
#         dir, so `5.10.repos` would fail the very repo the carry stood in for
#
# .the arms
#   1. reach sync — no tree reads `absent`; a carried tree reads `carried`; a
#                   clone with no upstream still reads `detached`
#   2. reach upsert — over a carried tree, every row is driven from the files
#                   it holds, and the report names a carry, not an absent clone
#   3. repos state — a carried tree reads `carried`; an empty dir stays
#                   `absent`; a clone stays `whole`
#   4. repos upsert — a carried tree is moved aside, kept, and the clone lands
#
# .what it does to the box
#   - every write lands under one `mktemp -d` HOME, removed on exit
#   - `aws`, `rhx`, and `gh` are stubs on PATH; no network, no credential
#   - every role name and account id is a fixture value
#
# usage:
#   rhx play.run --play prove.carried-tree-serves-reach
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.carried-tree-serves-reach"
echo "   └─ subject: 5.13.reach _sync + configure.upsert · 5.10.repos _state + provision.upsert"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
DEV="$ROOT/src/grove.provision/5.devtools"
SUBJECTS=(
  "$ROOT/src/grove.env.sh"   # the seat predicates every phase asks first, as the entrypoint loads them
  "$ROOT/src/grove.org.sh"
  "$ROOT/src/grove.aws.sh"   # the trust-refusal reader the upsert and verify share
  "$DEV/5.12.rack/_.sh"
  "$DEV/5.13.reach/_.sh"
  "$DEV/5.13.reach/configure.upsert.sh"
  "$DEV/5.13.reach/configure.verify.sh"
  "$DEV/5.12.rack/configure.upsert.sh"
  "$DEV/5.12.rack/configure.verify.sh"
  "$DEV/5.10.repos/_.sh"
  "$DEV/5.10.repos/provision.upsert.sh"
  "$DEV/5.10.repos/provision.verify.sh"
)
for f in "${SUBJECTS[@]}"; do
  [[ -f "$f" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $f" >&2; exit 2; }
done

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}
# .what = each report a human reads, masked of per-run paths, for one transcript snap
transcript=""
record() {
  local text="${2//$FIX/<fix>}"
  text="${text//$ROOT/<root>}"
  text="$(sed -E 's/\.carried\.[0-9A-Za-z:._-]+/.carried.<stamp>/g' <<<"$text")"
  transcript+="## $1"$'\n'"$text"$'\n\n'
}
has()    { [[ "$1" == *"$2"* ]]; }
hasnot() { [[ "$1" != *"$2"* ]]; }
eq()     { [[ "$1" == "$2" ]]; }

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT

export HOME="$FIX/home"
export GROVE_ORG=ahbode
export GROVE_SRC="$ROOT/src"
mkdir -p "$HOME/.aws" "$FIX/bin"
: > "$HOME/.aws/config"

# ── stubs
#   aws: an ambient identity answers
#   rhx: logs each call, succeeds
#   gh:  authed; lists one repo; a clone refuses a non-empty dir, as gh does
cat > "$FIX/bin/aws" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat > "$FIX/bin/rhx" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$FIX/rhx.calls"
exit 0
STUB
cat > "$FIX/bin/gh" <<STUB
#!/usr/bin/env bash
case "\$1 \$2" in
  "auth status") exit 0 ;;
  "repo list")   printf 'ahbode/infrastructure\tthe infra\n'; exit 0 ;;
  "repo clone")
    into="\$4"
    if [[ -d "\$into" && -n "\$(ls -A "\$into")" ]]; then
      echo "fatal: destination path '\$into' already exists and is not an empty directory." >&2
      exit 1
    fi
    mkdir -p "\$into/.git"; echo 'ref: refs/heads/main' > "\$into/.git/HEAD"; exit 0 ;;
esac
exit 0
STUB
chmod +x "$FIX/bin/"*
export PATH="$FIX/bin:$PATH"

# ── the subjects, sourced as the driver would
# shellcheck source=/dev/null
for f in "${SUBJECTS[@]}"; do source "$f"; done

INFRA="$HOME/git/ahbode/infrastructure"

# lay a carried tree: the three declaration files, fixture values, no .git
carry() {
  mkdir -p "$INFRA/provision/aws.auth"
  cat > "$INFRA/provision/aws.auth/resources.role-names.ts" <<'TS'
export const GROVE_ROLE_NAME = {
  prepPower: 'fixture-prep-power',
  prodReader: 'fixture-prod-reader',
} as const;
TS
  cat > "$INFRA/provision/aws.auth/resources.reach-arns.ts" <<'TS'
export const ACCOUNT_ID_EHMPATHY_DEMO = '999999999999' as const;
export const DEMO_POWER_ROLE_NAME = 'fixture-demo-power' as const;
TS
  cat > "$INFRA/declapract.use.yml" <<'YML'
variables:
  awsAccountId:
    prep: 123456789012
    prod: 111122223333
YML
}

echo "── arm 1: 5.13.reach _sync"
claim "no tree reads absent" eq "$(grove_provision_5_13_reach_sync)" absent
mkdir -p "$INFRA"
claim "an empty dir reads absent, as 5.10 reads it" eq "$(grove_provision_5_13_reach_sync)" absent
carry
claim "a carried tree (no .git) reads carried" eq "$(grove_provision_5_13_reach_sync)" carried

# a real clone with no upstream: the extant states still hold
CLONE="$FIX/clone"; cp -r "$INFRA" "$CLONE"
git -C "$INFRA" init -q -b main
git -C "$INFRA" -c user.email=f@example.com -c user.name=f add -A
git -C "$INFRA" -c user.email=f@example.com -c user.name=f commit -qm fixture
claim "a clone with no upstream still reads detached" eq "$(grove_provision_5_13_reach_sync)" detached
rm -rf "$INFRA"; cp -r "$CLONE" "$INFRA"
echo ""

echo "── arm 2: 5.13.reach configure.upsert over a carried tree"
out="$(grove_provision_5_13_reach_configure_upsert 2>&1)"; rc=$?
calls="$(cat "$FIX/rhx.calls" 2>/dev/null)"
record "5.13.reach configure.upsert over a carried tree (rc $rc)" "$out"
claim "the upsert exits 0" eq "$rc" 0
claim "the report names a carried tree" has "$out" "is a carried tree (no .git)"
claim "the report does not call it not cloned" hasnot "$out" "is not cloned"
claim "the report hands no 5.10.repos fix" hasnot "$out" "--what 5.10.repos"
claim "the report names how to re-carry" has "$out" "--into git/ahbode/infrastructure"
claim "every row is driven: 5 aws.reach.set calls" eq "$(grep -c 'aws.reach.set' <<<"$calls")" 5
claim "prep rows assume the role the carried tree declares" has "$calls" "--env prep --owner ehmpath --assume fixture-prep-power --account 123456789012"
claim "the prod row reads its own key" has "$calls" "--env prod --owner ehmpath --assume fixture-prod-reader --account 111122223333"
claim "the demo row reads the carried arn consts" has "$calls" "--org ehmpathy --env prep --owner ehmpath --assume fixture-demo-power --account 999999999999"
claim "no row declined" hasnot "$out" "declined"
claim "no phase called an undefined function" hasnot "$out" "command not found"
echo ""

echo "── arm 2b: 5.13.reach configure.upsert, a role that refuses the session's tags"
# the apply path is the one a first hetzner apply runs: its refusal must name the
#   SESSION ask (the role trusts this box), never the bare trust-policy ask
cat > "$FIX/bin/rhx" <<'STUB'
#!/usr/bin/env bash
echo "An error occurred (AccessDenied) when calling the AssumeRole operation: User: <principal> is not authorized to perform: sts:TagSession on resource: <role>" >&2
exit 1
STUB
chmod +x "$FIX/bin/rhx"
out="$(grove_provision_5_13_reach_configure_upsert 2>&1)"; rc=$?
record "5.13.reach configure.upsert, a session-tag refusal (rc $rc)" "$out"
claim "the upsert fails on the refusal" eq "$([[ "$rc" -ne 0 ]] && echo y)" y
claim "it names the role as one that TRUSTS this box" has "$out" "the role TRUSTS this box, and refuses what its session carries"
claim "it names all three actions owed" has "$out" "sts:TagSession"
claim "it does not call this box outside the trust policy" hasnot "$out" "outside its trust policy"
echo ""

echo "── arm 2c: 5.13.reach configure.upsert, a role that does not trust this box (c14)"
cat > "$FIX/bin/rhx" <<'STUB'
#!/usr/bin/env bash
echo "An error occurred (AccessDenied) when calling the AssumeRole operation: User: <principal> is not authorized to perform: sts:AssumeRole on resource: <role>" >&2
exit 1
STUB
chmod +x "$FIX/bin/rhx"
out="$(grove_provision_5_13_reach_configure_upsert 2>&1)"; rc=$?
record "5.13.reach configure.upsert, a bare AssumeRole refusal (rc $rc)" "$out"
claim "c14 · the upsert fails on the refusal" eq "$([[ "$rc" -ne 0 ]] && echo y)" y
claim "c14 · it names the box outside the role's trust policy, as the 2nd cause" has "$out" "the role EXISTS and this box sits outside its"
claim "c14 · it asks the org question first, in the verify's own words" has "$out" "ask 1 FIRST. its answer is the ORG's"
claim "c14 · it never reads a bare AssumeRole as a session refusal" hasnot "$out" "refuses what its session carries"
claim "c14 · it replays what the skill said" has "$out" "is not authorized to perform: sts:AssumeRole"
echo ""

echo "── arm 2d: 5.13.reach configure.upsert, a hand-laid twin of the hop's profile (c11)"
cat > "$FIX/bin/rhx" <<'STUB'
#!/usr/bin/env bash
# name the profile THIS call asked for — a constant would pin one row's name on every row
org=""; env=""
while (( $# )); do
  case "$1" in --org) org="$2"; shift ;; --env) env="$2"; shift ;; esac
  shift
done
echo "   └─ ✋ ConstraintError: <cfg> already declares [profile $org.$env] OUTSIDE this skill's fence" >&2
echo "      └─ where: <cfg>, lines 4-7" >&2
exit 2
STUB
chmod +x "$FIX/bin/rhx"
out="$(grove_provision_5_13_reach_configure_upsert 2>&1)"; rc=$?
record "5.13.reach configure.upsert, an unfenced twin (rc $rc)" "$out"
claim "c11 · the upsert fails on the twin" eq "$([[ "$rc" -ne 0 ]] && echo y)" y
claim "c11 · it names the twin, never the generic branch" has "$out" "already holds this hop's profile OUTSIDE the fence"
claim "c11 · it does not fall to the generic branch" hasnot "$out" "neither an"
claim "c11 · it replays the skill's line numbers" has "$out" "lines 4-7"

echo ""

echo "── arm 2f: one row refuses, the other rows proceed (case=6 [t1])"
# a refusal on ONE hop must not cost the box its other hops: each row is its own fact
rm -f "$FIX/rhx.calls"
cat > "$FIX/bin/rhx" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$FIX/rhx.calls"
[[ "\$*" == *"--org ehmpathy --env test"* ]] && { echo "An error occurred (AccessDenied) when calling the AssumeRole operation: User: <principal> is not authorized to perform: sts:AssumeRole on resource: <role>" >&2; exit 1; }
exit 0
STUB
chmod +x "$FIX/bin/rhx"
out="$(grove_provision_5_13_reach_configure_upsert 2>&1)"; rc=$?
calls="$(cat "$FIX/rhx.calls" 2>/dev/null)"
record "5.13.reach configure.upsert, one row refuses (rc $rc)" "$out"
claim "case=6 · the upsert fails, so the refusal is never lost" eq "$([[ "$rc" -ne 0 ]] && echo y)" y
claim "case=6 · every row is still driven: 5 aws.reach.set calls" eq "$(grep -c 'aws.reach.set' <<<"$calls")" 5
claim "case=6 · the row after the refused one is driven" has "$calls" "--org ehmpathy --env prep --owner ehmpath --assume fixture-demo-power"
claim "case=6 · the refusal names the row it refused" has "$out" "could not give this seat reach into ehmpathy.test"
claim "case=6 · the row after it reaches its account" has "$out" "ehmpathy.prep reaches its account, proven with a live sts call ✔"

cat > "$FIX/bin/rhx" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$FIX/rhx.calls"
exit 0
STUB
chmod +x "$FIX/bin/rhx"
echo ""

echo "── arm 2e: no ambient identity — a laptop declines, a camp seat halts"
# a stopped signer on a camp seat must never read as the decline a laptop owes:
#   the apply every fix-text names would otherwise print success and lay no hop
cat > "$FIX/bin/aws" <<'STUB'
#!/usr/bin/env bash
echo "Unable to locate credentials" >&2
exit 255
STUB
chmod +x "$FIX/bin/aws"
for server in local@unix cloud@hetzner.hetzbot cloud@aws.ec2; do
  out="$(GROVE_ENV_SERVER="$server" GROVE_ENV_SEAT=camper grove_provision_5_13_reach_configure_upsert 2>&1)"; rc=$?
  record "5.13.reach configure.upsert, no ambient identity, $server (rc $rc)" "$out"
  if [[ "$server" == local@* ]]; then
    claim "$server · upsert declines, rc 0" bash -c '[[ "$1" == *"🌙 declined — no ambient identity"* && "$2" -eq 0 ]]' _ "$out" "$rc"
  else
    claim "$server · upsert halts ✋, rc 1" bash -c '[[ "$1" == *"✋ no ambient identity answers on this camp seat"* && "$2" -eq 1 ]]' _ "$out" "$rc"
    claim "$server · upsert names the identity bundle" has "$out" "rhx grove.provision --what 5.6.aws --mode plan"
    claim "$server · upsert never says an off-camp decline is correct" hasnot "$out" "off camp this is correct"
  fi
done
# every reader of the ambient identity gives the one verdict — never the upsert alone
for fn in grove_provision_5_13_reach_configure_verify grove_provision_5_12_rack_upsert_awsprofile grove_provision_5_12_rack_verify_awsprofile; do
  out="$(GROVE_ENV_SERVER=cloud@hetzner.hetzbot GROVE_ENV_SEAT=camper "$fn" "$FIX" 2>&1)"; rc=$?
  record "$fn, no ambient identity, cloud@hetzner.hetzbot (rc $rc)" "$out"
  claim "$fn · camp seat → ✋ rc 1" bash -c '[[ "$1" == *"✋ no ambient identity answers on this camp seat"* && "$2" -eq 1 ]]' _ "$out" "$rc"
  out="$(GROVE_ENV_SERVER=local@unix "$fn" "$FIX" 2>&1)"; rc=$?
  record "$fn, no ambient identity, local@unix (rc $rc)" "$out"
  claim "$fn · laptop → 🌙, rc 0" bash -c '[[ "$1" == *"🌙 declined — no ambient identity"* && "$2" -eq 0 ]]' _ "$out" "$rc"
done
claim "hetzner · names infra's signer as a cause" has "$(GROVE_ENV_SERVER=cloud@hetzner.hetzbot GROVE_ENV_SEAT=camper grove_provision_5_13_reach_configure_upsert 2>&1)" "a stopped signer unit"
claim "ec2 · names no hetzner signer" hasnot "$(GROVE_ENV_SERVER=cloud@aws.ec2 GROVE_ENV_SEAT=camper grove_provision_5_13_reach_configure_upsert 2>&1)" "signer"
cat > "$FIX/bin/aws" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$FIX/bin/aws"
echo ""

echo "── arm 3: 5.10.repos _state"
claim "a carried tree reads carried" eq "$(grove_provision_5_10_repos_state "$INFRA")" carried
mkdir -p "$FIX/empty"
claim "an empty dir stays absent" eq "$(grove_provision_5_10_repos_state "$FIX/empty")" absent
claim "no dir stays absent" eq "$(grove_provision_5_10_repos_state "$FIX/none")" absent
mkdir -p "$FIX/whole/.git"; echo 'ref: refs/heads/main' > "$FIX/whole/.git/HEAD"
claim "a clone stays whole" eq "$(grove_provision_5_10_repos_state "$FIX/whole")" whole
mkdir -p "$FIX/worktree"; echo 'gitdir: /elsewhere/.git/worktrees/x' > "$FIX/worktree/.git"; echo x > "$FIX/worktree/readme.md"
claim "a worktree (a .git FILE) reads whole, never carried" eq "$(grove_provision_5_10_repos_state "$FIX/worktree")" whole
echo ""

echo "── arm 3b: 5.10.repos provision.verify over a carried tree, as a plan reads it"
export GROVE_GIT_ORGS=ahbode
out="$(GROVE_ENV_SERVER=local@unix GROVE_MODE=plan grove_provision_5_10_repos_provision_verify 2>&1)"; rc=$?
record "5.10.repos provision.verify over a carried tree, laptop plan (rc $rc)" "$out"
claim "a laptop plan says its tree stays in place" has "$out" "on a laptop each is the human's own tree: an apply leaves it in place"
out="$(GROVE_ENV_SERVER=local@unix grove_provision_5_10_repos_provision_upsert 2>&1)"; rc=$?
record "5.10.repos provision.upsert over a carried tree, laptop (rc $rc)" "$out"
claim "a laptop's carried tree is left in place, uncloned" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"a laptop'"'"'s tree is left in place"* && ! -e "$3/.git" ]] && compgen -G "$3.carried.*" | grep -c . | grep -qx 0' _ "$rc" "$out" "$INFRA"
out="$(GROVE_ENV_SERVER=cloud@hetzner.hetzbot GROVE_MODE=plan grove_provision_5_10_repos_provision_verify 2>&1)"; rc=$?
record "5.10.repos provision.verify over a carried tree, plan (rc $rc)" "$out"
claim "the plan names the carried tree, before any move" has "$out" "hold files and no .git (a carried tree)"
claim "the plan names where the apply keeps it" has "$out" "moves each aside to '<repo>.carried.<stamp>'"
claim "the plan names the dir" has "$out" "$INFRA"
claim "the plan counts a carried tree as carried, never 'not on disk'" \
  bash -c '[[ "$1" == *"1 a carried tree"* && "$1" != *"not on disk"* && "$1" != *"every repo dir on disk opens"* ]]' _ "$out"
echo ""

echo "── arm 4: 5.10.repos provision.upsert over a carried tree"
out="$(GROVE_ENV_SERVER=cloud@hetzner.hetzbot grove_provision_5_10_repos_provision_upsert 2>&1)"; rc=$?
aside=( "$INFRA".carried.* )
record "5.10.repos provision.upsert over a carried tree (rc $rc)" "$out"
claim "the upsert exits 0" eq "$rc" 0
claim "the carried tree is moved aside" test -d "${aside[0]}"
claim "the moved tree keeps its files" test -f "${aside[0]}/provision/aws.auth/resources.role-names.ts"
claim "the clone lands where the carry stood" test -r "$INFRA/.git/HEAD"
claim "the run counts one clone, no failure" has "$out" "cloned: 1, already present: 0, failed: 0"
claim "the run names the kept dir" has "$out" "carried; moved aside"
claim "the run called no undefined function" hasnot "$out" "command not found"
echo ""

# shellcheck source=/dev/null
source "$ROOT/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$ROOT/.play/permanent/prove.carried-tree-serves-reach.snap" name=transcript actual="$transcript" \
  || failed=$((failed + 1))

echo "   └─ $passed held, $failed failed"
(( failed == 0 )) || exit 1
exit 0
