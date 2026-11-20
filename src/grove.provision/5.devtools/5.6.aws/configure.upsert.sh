#!/usr/bin/env bash
######################################################################
# .what = declare the `ambient` aws profile on a cloud grove — the one
#         that names the box's OWN platform identity
#
# .why
#   - a cloud grove HAS an identity; without a profile, no consumer can name it
#     (📜 grove-1 2026-08-07: IMDS ✔, sts ✔, useKeyrack ✋ AWS_PROFILE unset)
#   - ec2 serves it at the sdk default; hetzner at infra's signer on loopback,
#     named in camper's [default]; a laptop serves neither, so it declines
#   - 🛑 [default] is this bundle's on ec2 and infra's on hetzner, so the swap
#     refuses a body that changes one it does not own (`src/grove.aws.sh`)
#   - a POINTER, never a stored credential: an instance role's keys rotate
#   - append-with-marker, never a whole-file copy: the file holds a human's
#     sso profiles (`rule.forbid.two-writers-on-one-artifact`)
#
# guarantee:
#   - the marker fence is rewritten in place, so N runs = 1 block
#   - an unchanged body writes no byte
#   - it writes no secret, since the profile names an identity
######################################################################

grove_provision_5_6_aws_configure_upsert() {
  grove_env_seat_is_admin && { grove_env_seat_admin_declines "the camp aws identity"; return 0; }
  ####################################################################
  # 1. which identity endpoint does this platform serve?
  #   - judge the PLATFORM first, never a probe of 169.254.169.254: a hetzner
  #     grove has no route there, and a laptop that answers a stray IMDS would
  #     read as a grove
  #   - (`rule.require.aws-params-on-camp-groves-only` — the platform names HOW
  #     the identity arrives; that a camp grove HAS one is mandated, and asserted here)
  ####################################################################
  local endpoint road cfg
  cfg="$(grove_aws_config)"
  endpoint="$(grove_aws_identity_endpoint)"; road="$(grove_aws_identity_road "$?")"

  # a camp grove on a platform this repo has no identity road for is a fault: the
  #   identity is mandated, so the gap is ours to teach, never a decline
  if [[ "$road" == unmapped ]]; then
    echo "   ✋ ConstraintError: ${GROVE_ENV_SERVER} is a camp grove, and this repo knows no road to its aws identity" >&2
    echo "      ⇒ a camp grove carries the camp identity by mandate; only aws.ec2 (IMDS) and" >&2
    echo "        hetzner.hetzbot (infra's IAM Roles Anywhere signer) are mapped" >&2
    echo "      fix: teach grove_aws_identity_endpoint (src/grove.aws.sh) this platform's road" >&2
    return 1
  fi
  if [[ "$road" == no-identity ]]; then
    echo "   🌙 declined — ${GROVE_ENV_SERVER:-this box} serves no platform identity, so there"
    echo "      is no ambient identity to name. a laptop's aws profiles are its human's to place"
    return 0
  fi

  # the empty credentials file is owed on EVERY cloud grove, identity live or not:
  # a zsh there sets AWS_SDK_LOAD_CONFIG=1, and an sdk that loads throws on its absence
  grove_provision_5_6_aws_credentials_findsert || return 1

  # 🛑 a camp grove's aws identity is a MANDATED PREREQ, on every seat
  #   (`rule.require.aws-params-on-camp-groves-only`). every later reader — the
  #   rack's `aws.params` slug, the reach hops, every suite — relies on it, so an
  #   absent identity is a ✋ that names its owner, never a 🌙 that lets the run
  #   pass and fail later on a credential nobody connects to this line
  if [[ "$road" == serve-unwired ]]; then
    echo "   ✋ ConstraintError: [default] in $cfg names no ec2_metadata_service_endpoint, so this seat has no aws identity" >&2
    echo "      ⇒ a camp grove carries the camp identity on EVERY seat; on hetzner that" >&2
    echo "        line is this seat's one road to infra's IAM Roles Anywhere signer" >&2
    echo "      ⇒ this bundle mirrors that line and never invents it: [default] is infra's" >&2
    echo "      fix (infra): run ahbode/infrastructure's grove identity skill for THIS seat," >&2
    echo "        with serve wired; then" >&2
    echo "        rhx grove.provision --what 5.6.aws --mode apply" >&2
    return 1
  fi

  if [[ "$road" == bad-endpoint ]]; then
    echo "   ✋ ConstraintError: [default] in $cfg names ec2_metadata_service_endpoint = '$endpoint'" >&2
    echo "      ⇒ that is not a loopback http url, and every profile this repo lays would" >&2
    echo "        send its identity requests there — to another host, or to naught" >&2
    echo "      fix: re-run infra's grove identity skill, which writes" >&2
    echo "        http://127.0.0.1:<port>, then rhx grove.provision --what 5.6.aws --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 2. does the endpoint answer with a role?
  #   - a profile that named a dead endpoint would fail later and less clearly
  #   - bounded: an IMDS with no route HANGS rather than refuses
  ####################################################################
  local base imds_token role
  base="$(grove_aws_imds_base "$endpoint")"
  # the metadata-token header sits on the curl line itself: `wire.verify` exempts
  # an imds call by that marker, and a bounded loopback call is no wire fetch
  imds_token="$(curl -sS -m 3 -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' \
    -X PUT "$base/latest/api/token" 2>/dev/null)"

  if [[ -z "$imds_token" ]]; then
    echo "   ✋ ConstraintError: ${GROVE_ENV_SERVER} declares a platform identity at $base, and it gave no token" >&2
    echo "      ⇒ a profile that named it would point at an identity that cannot answer" >&2
    local service="the instance's metadata service is on (http-tokens, hop limit)"
    [[ -n "$endpoint" ]] && service="infra's signer serves on $base (systemctl status of its serve unit)"
    echo "      fix: confirm $service," >&2
    echo "        then rhx grove.provision --what 5.6.aws --mode apply" >&2
    return 1
  fi

  role="$(curl -sS -m 3 -H "X-aws-ec2-metadata-token: $imds_token" \
    "$base/latest/meta-data/iam/security-credentials/" 2>/dev/null)"

  if [[ -z "$role" ]]; then
    echo "   ✋ ConstraintError: the identity endpoint answers, but names NO role" >&2
    echo "      ⇒ a profile that named it would point at an absent identity, and" >&2
    echo "        every consumer aimed there would fail later and less clearly" >&2
    echo "      fix: attach an iam role to the box (ec2: an instance profile; hetzner:" >&2
    echo "        infra's roles-anywhere profile), then re-apply" >&2
    return 1
  fi

  ####################################################################
  # 3. the body, per platform
  ####################################################################
  local region default_before own body
  default_before="$(grove_aws_config_section cfg="$cfg" name=default)"
  region="$(grove_provision_5_6_aws_region_of "$(grove_aws_config_value cfg="$cfg" name=default key=region)")"

  # ec2 owns the [default] it mirrors; hetzner keeps infra's (`grove_provision_5_6_aws_fence_body`)
  own=own
  [[ -n "$endpoint" ]] && own=keep
  body="$(grove_provision_5_6_aws_fence_body "$endpoint" "$region")"

  ####################################################################
  # 4. rewrite in place — the fence is set WHERE IT STANDS, then swapped atomically
  #   - a plain append grows the file on every apply
  #   - a drop-then-append moves the block past `aws.reach.set`'s fences, so
  #     each bundle's run rewrote the file the other left (`grove_aws_config_fence_set`)
  #   - a `grep -q` guard would skip a block whose CONTENTS changed
  #
  # 🛑 the LEGACY fence — every box converged before 2026-09-02 carries it
  #   - the fence word moved `# devenv:` → `# grove:` at the suite cutover
  #   - ⇒ dropped by its old pair too, or `~/.aws/config` would hold TWO
  #     `[profile ambient]` sections, and the last wins in silence
  ####################################################################
  mkdir -p "$(dirname "$cfg")" || return 1
  touch "$cfg" || return 1

  local tmp
  tmp="$(grove_aws_config_tmp)" || return 1
  grove_aws_config_fence_set cfg="$cfg" \
    open="$GROVE_UPGRADE_5_6_AWS_FENCE_OPEN" shut="$GROVE_UPGRADE_5_6_AWS_FENCE_SHUT" \
    open_was='# devenv: the ambient ec2 instance role, as a profile' shut_was='# devenv: end' \
    header='[profile ambient]' body="$body" > "$tmp" || { rm -f "$tmp"; return 1; }

  if cmp -s "$tmp" "$cfg"; then
    rm -f "$tmp"
    echo "   • the 'ambient' profile is current ✔ (role: $role, region: $region; no write)"
    [[ "$own" == keep ]] && echo "   • [default] read, never written ✔ (infra's identity skill owns it)"
    return 0
  fi

  local rc   # the bundle runs sourced inside the driver: a bare `rc` would leak into it
  grove_aws_config_swap cfg="$cfg" new="$tmp" default_before="$default_before" default="$own"; rc=$?
  if (( rc != 0 )); then
    echo "   💥 MalfunctionError: ~/.aws/config was NOT written: $(grove_aws_config_swap_why "$rc")" >&2
    grove_aws_config_swap_said "      " >&2
    echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
    return 1
  fi

  echo "   • the 'ambient' profile is declared ✔ (role: $role, region: $region)"
  [[ -n "$endpoint" ]] && echo "     .endpoint = $endpoint, mirrored from [default]"
  [[ "$own" == keep ]] && echo "   • [default] read, never written ✔ (infra's identity skill owns it)"
  echo "     .note = it names the platform's role; it stores no credential"
  return 0
}

######################################################################
# .what = the EMPTY credentials file that `AWS_SDK_LOAD_CONFIG=1` demands
#
# ⚠️ an empty file is load-bear, never clutter
#   - `2.shell/2.5.zsh/zshrc.sh` exports `AWS_SDK_LOAD_CONFIG=1`, which routes v2's
#     region read through a loader that opens this file UNCONDITIONALLY
#   - with the file absent it does not fall back, it throws:
#
#       Error: ENOENT: no such file or directory, open '~/.aws/credentials'
#         at IniLoader.parseFile  (aws-sdk/lib/shared-ini/ini-loader.js:6)
#         at Config.region        (aws-sdk/lib/node_loader.js:100)
#
#   - 📜 grove-1 2026-08-06: four suites died there, credentials already held
#   - ⇒ the file must exist and must stay EMPTY, since content is a credential
#
# .findsert, never upsert — a human's own credentials file is theirs
######################################################################
grove_provision_5_6_aws_credentials_findsert() {
  local creds="$HOME/.aws/credentials"
  if [[ -e "$creds" ]]; then
    echo "   • ~/.aws/credentials already present; left untouched ✔"
    return 0
  fi

  mkdir -p "$HOME/.aws" || return 1
  {
    printf '%s\n' '# grove: intentionally EMPTY.'
    printf '%s\n' '# aws-sdk v2 opens this file unconditionally when AWS_SDK_LOAD_CONFIG=1,'
    printf '%s\n' '# which 2.shell/2.5.zsh/zshrc.sh sets. an absent file throws ENOENT from Config.region.'
    printf '%s\n' '# this box has no key to store: its identity is ambient (the platform'
    printf '%s\n' '# role), declared as [profile ambient] in ~/.aws/config.'
  } > "$creds" || return 1
  chmod 600 "$creds" || return 1
  echo "   • ~/.aws/credentials created, EMPTY ✔ (aws-sdk v2 opens it unconditionally)"
}
