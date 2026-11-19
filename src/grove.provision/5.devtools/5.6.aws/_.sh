#!/usr/bin/env bash
# .what = the aws cli, and the ssm session-manager plugin it shells out to
# .why
#   - the plugin rides in THIS bundle: a human never invokes it, only the
#     cli, which fails "not found" when it is absent
#   - every grove here is REACHED through ssm, so a grove needs the cli to
#     reach the NEXT grove, a laptop the first
#   - configure names the `ambient` profile — without it a grove holds an
#     identity no consumer can address
#
# usage:
#   rhx grove.provision --what 5.6.aws --mode apply

# .what = the aws cli version this repo installs, declared ONCE
# .why the upsert and the state reader both compare against it; two
#   declarations of one fact are free to drift (rule.require.bundle-as-sole-declaration)
GROVE_UPGRADE_5_6_AWS_CLI_AT="2.36.23"

# .what = the fence markers this bundle owns in ~/.aws/config, declared ONCE
# .why the upsert drops by them and the verify reads by them; two copies drift,
#   and a verify sourced alone must not lean on the upsert's file
GROVE_UPGRADE_5_6_AWS_FENCE_OPEN='# grove: the ambient ec2 instance role, as a profile'
GROVE_UPGRADE_5_6_AWS_FENCE_SHUT='# grove: end'

# .what = the region a profile this bundle lays carries, by precedence:
#   [default]'s own region → AWS_REGION → AWS_DEFAULT_REGION → us-east-1
grove_provision_5_6_aws_region_of() {
  local region_default="$1"
  [[ -n "$region_default" ]] && { printf '%s' "$region_default"; return 0; }
  [[ -n "${AWS_REGION:-}" ]] && { printf '%s' "$AWS_REGION"; return 0; }
  printf '%s' "${AWS_DEFAULT_REGION:-us-east-1}"
}

# .what = the body this bundle fences into ~/.aws/config (a transformer)
# .why  = one composition, two platforms: hetzner adds the signer's endpoint and
#   lays no [default] (infra's identity skill owns it); ec2 mirrors [default] so
#   an sdk with no AWS_PROFILE still finds a region
#   (📜 grove-1 2026-08-06: 22 of 31 tests died on "Missing region in config")
# .note = $1 = the identity endpoint ('' on ec2) · $2 = the region
grove_provision_5_6_aws_fence_body() {
  local endpoint="$1" region="$2"
  printf '%s\n' "$GROVE_UPGRADE_5_6_AWS_FENCE_OPEN"
  printf '[profile ambient]\n'
  printf 'credential_source = Ec2InstanceMetadata\n'
  [[ -n "$endpoint" ]] && printf 'ec2_metadata_service_endpoint = %s\n' "$endpoint"
  printf 'region = %s\n' "$region"
  [[ -z "$endpoint" ]] && printf '\n[default]\ncredential_source = Ec2InstanceMetadata\nregion = %s\n' "$region"
  printf '%s\n' "$GROVE_UPGRADE_5_6_AWS_FENCE_SHUT"
}

# .what = does this bundle's fence in the config hold a [default] block?
# .why on hetzner [default] is infra's; a second one inside our fence shadows it
grove_provision_5_6_aws_fence_holds_default() {
  local cfg="$1"
  awk -v o="$GROVE_UPGRADE_5_6_AWS_FENCE_OPEN" -v s="$GROVE_UPGRADE_5_6_AWS_FENCE_SHUT" '
    $0 == o { f = 1; next }
    $0 == s { f = 0; next }
    f && /^\[[[:space:]]*default[[:space:]]*\]/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$cfg"
}

# .what = which of FOUR states is this box's `aws` in?
#   `..._cli_state` → whole | adrift | wrong | absent | unknown
# .why
#   - ONE reader, asked by BOTH halves — debian's v1 `awscli` answers
#     `command -v` but fails an `aws-cli/2.*` match, two readers would disagree
#   - the read is BOUNDED — the v2 cli unpacks a bundled python runtime
#     before its first byte, and this runs on every plan
#   - .refs = gotcha.5-6-aws-cli-two-readers.demo=v1-debian-package
#
# stdout: whole = declared version; adrift = other v2; wrong = v1;
#   absent = no aws on PATH; unknown = no answer within the bound
grove_provision_5_6_aws_cli_state() {
  command -v aws >/dev/null 2>&1 || { echo absent; return 0; }

  local ver
  ver="$(timeout -k 5 20 aws --version 2>&1 | head -1)"

  [[ -n "$ver" ]]             || { echo unknown; return 0; }
  [[ "$ver" == aws-cli/2.* ]] || { echo wrong; return 0; }

  # the banner reads `aws-cli/2.36.23 Python/… Linux/…`, matched with the
  # space after the version so `2.36.2` cannot read as `2.36.23`
  [[ "$ver" == "aws-cli/$GROVE_UPGRADE_5_6_AWS_CLI_AT "* ]] || { echo adrift; return 0; }

  echo whole
}

# .what = the verify's verdict on the identity road, before any claim reads a file
# .why  = a camp grove's identity is a MANDATED prereq on every seat
#   (`rule.require.aws-params-on-camp-groves-only`), so a road it lacks is a ✋
# .note = rc 0 = proceed · 1 = refused (named) · 3 = not applicable (🌙 said)
grove_provision_5_6_aws_road_verify() {
  local road="$1" cfg="$2" endpoint="$3"
  case "$road" in
    unmapped)
      echo "   ✋ ConstraintError: ${GROVE_ENV_SERVER} is a camp grove, and this repo knows no road to its aws identity" >&2
      echo "      fix: teach grove_aws_identity_endpoint (src/grove.aws.sh) this platform's road" >&2
      return 1 ;;
    no-identity)
      echo "   🌙 not applicable — ${GROVE_ENV_SERVER:-this box} serves no platform identity"
      return 3 ;;
    serve-unwired)
      echo "   ✋ ConstraintError: [default] in $cfg names no ec2_metadata_service_endpoint, so this seat has no aws identity" >&2
      echo "      ⇒ a camp grove carries the camp identity on EVERY seat; on hetzner that line" >&2
      echo "        is this seat's one road to infra's IAM Roles Anywhere signer" >&2
      echo "      fix (infra): run ahbode/infrastructure's grove identity skill for THIS seat," >&2
      echo "        with serve wired; then rhx grove.provision --what 5.6.aws --mode apply" >&2
      return 1 ;;
    bad-endpoint)
      echo "   ✋ ConstraintError: [default] in $cfg names a non-loopback ec2_metadata_service_endpoint ('$endpoint')" >&2
      echo "      fix: re-run infra's grove identity skill, then rhx grove.provision --what 5.6.aws --mode apply" >&2
      return 1 ;;
  esac
  return 0
}

grove_provision_5_6_aws() {
  bundle.upgrade 5.6.aws.provision.upsert
  bundle.upgrade 5.6.aws.provision.verify
  bundle.upgrade 5.6.aws.configure.upsert
  bundle.upgrade 5.6.aws.configure.verify
}
