#!/usr/bin/env bash
######################################################################
# .what = prove a cloud grove's ADMIN seat (`ground`) holds no aws identity and
#         does no credentialed work: every such phase declines there, rc 0
#
# .why  = ground converges box-wide facts and holds sudo; the camper does the work
#         and carries the camp identity (`rule.require.aws-params-on-camp-groves-only`).
#         📜 2026-11-16 on hetzner: ground's apply raised 6 claims from ONE cause —
#         no aws identity on a seat that was never meant to hold one
#
# guarantee:
#   - hermetic: each phase returns at its guard; no network, no rack, no root
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEV="$HERE/src/grove.provision/5.devtools"

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}

echo "🌲 prove.admin-seat-holds-no-credentials"

# shellcheck source=/dev/null
source "$HERE/src/grove.env.sh"

####################################################################
# arm 1 — the truth table: tier × seat
####################################################################
is() { ( export GROVE_ENV_SERVER="$1" GROVE_ENV_SEAT="$2"; "$3" ); }
check "cloud · ground is the admin seat"       is cloud@hetzner.hetzbot ground grove_env_seat_is_admin
check "cloud · camper is no admin seat"        bash -c '! "$@"' _ is cloud@hetzner.hetzbot camper grove_env_seat_is_admin
check "ec2 · ground is the admin seat too"     is cloud@aws.ec2 ground grove_env_seat_is_admin
check "local · a user named ground is no admin seat" bash -c '! "$@"' _ is local@unix ground grove_env_seat_is_admin
check "house · a user named ground is no admin seat" bash -c '! "$@"' _ is house@unix ground grove_env_seat_is_admin

####################################################################
# arm 2 — every credentialed phase declines on the admin seat, rc 0
####################################################################
phases=(
  "5.6.aws configure.upsert grove_provision_5_6_aws_configure_upsert"
  "5.6.aws configure.verify grove_provision_5_6_aws_configure_verify"
  "5.12.rack configure.upsert grove_provision_5_12_rack_configure_upsert"
  "5.12.rack configure.verify grove_provision_5_12_rack_configure_verify"
  "5.4.gh configure.upsert grove_provision_5_4_gh_configure_upsert"
  "5.4.gh configure.verify grove_provision_5_4_gh_configure_verify"
  "5.10.repos provision.upsert grove_provision_5_10_repos_provision_upsert"
  "5.10.repos provision.verify grove_provision_5_10_repos_provision_verify"
  "5.10.repos configure.upsert grove_provision_5_10_repos_configure_upsert"
  "5.10.repos configure.verify grove_provision_5_10_repos_configure_verify"
  "5.13.reach configure.upsert grove_provision_5_13_reach_configure_upsert"
  "5.13.reach configure.verify grove_provision_5_13_reach_configure_verify"
  "5.15.identity configure.upsert grove_provision_5_15_identity_configure_upsert"
  "5.15.identity configure.verify grove_provision_5_15_identity_configure_verify"
  "5.16.keys configure.verify grove_provision_5_16_keys_configure_verify"
)
# every decline a human reads on the admin seat, for one transcript snap
transcript=""
for row in "${phases[@]}"; do
  read -r bundle phase fn <<< "$row"
  out="$(
    export GROVE_ENV_SERVER=cloud@hetzner.hetzbot GROVE_ENV_SEAT=ground
    # shellcheck source=/dev/null
    source "$HERE/src/grove.env.sh"
    # shellcheck source=/dev/null
    source "$DEV/$bundle/$phase.sh"
    "$fn" 2>&1
  )"; rc=$?
  transcript+="## $bundle $phase (rc $rc)"$'\n'"${out//$HERE/<root>}"$'\n\n'
  check "$bundle $phase · admin seat declines (rc 0)" \
    bash -c '[[ "$1" -eq 0 && "$2" == *"ADMIN seat"* ]]' _ "$rc" "$out"
done

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.admin-seat-holds-no-credentials.snap" name=transcript actual="$transcript" \
  || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.admin-seat-holds-no-credentials: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
