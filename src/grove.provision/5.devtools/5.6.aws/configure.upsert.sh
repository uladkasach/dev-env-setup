#!/usr/bin/env bash
######################################################################
# .what = declare the `ambient` aws profile on a cloud grove — the one
#         that names the box's OWN ec2 instance role
#
# .a cloud grove already HAS an identity, and could not say so
#   - every grove is ec2, so IMDS always answers
#   - 📜 traced on grove-1, 2026-08-07:
#
#       IMDS                          ✔ role <camp-grove-role>
#       aws sts (bare)                ✔ account <camp-acct>
#       aws configure export-creds    ✔ emits the AWS_* export lines
#       useKeyrack                    ✋ throws — AWS_PROFILE is unset
#
#   - the credentials never failed to EXIST or to EXPORT — one POINTER was absent
#   - `credential_source = Ec2InstanceMetadata` says "this profile IS that role"
#   - ⇒ with it declared, every consumer that speaks profiles reaches it
#
# ⚠️ this is a PROFILE, never a stored credential
#   - an instance role's keys rotate on aws's clock and expire in hours
#   - ⇒ this writes a POINTER, which never expires, and no secret at all
#
# ⚠️ it declines on a laptop, which has no instance role
#   - ⇒ a profile that named one would point at an identity that cannot answer
#
# ⚠️ the write is APPEND-with-marker, never a whole-file copy
#   - `~/.aws/config` holds a human's sso profiles, which a copy would destroy
#   - ⇒ the block is fenced by a `# grove:` marker and rewritten in place
#   - (`rule.forbid.two-writers-on-one-artifact`)
#
# guarantee:
#   - the marker fence is rewritten in place, so N runs = 1 block
#   - it writes no secret, since the profile names an identity
######################################################################

grove_provision_5_6_aws_configure_upsert() {
  ####################################################################
  # 1. is there an instance role to point at?
  #   - ask IMDS, never `--for cloud`: a cloud grove with no role attached must
  #     decline too, and a tag cannot say
  #   - ⇒ judge the FACT you depend on
  ####################################################################
  local imds_token role
  imds_token="$(curl -sS -m 3 -X PUT 'http://169.254.169.254/latest/api/token' \
    -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null)"

  if [[ -z "$imds_token" ]]; then
    echo "   🌙 declined — no ec2 instance metadata here, so there is no ambient"
    echo "      identity to name. a laptop's aws profiles are its human's to place"
    return 0
  fi

  role="$(curl -sS -m 3 -H "X-aws-ec2-metadata-token: $imds_token" \
    'http://169.254.169.254/latest/meta-data/iam/security-credentials/' 2>/dev/null)"

  if [[ -z "$role" ]]; then
    echo "   ✋ IMDS answers, but NO instance role is attached to this box" >&2
    echo "      ⇒ a profile that named it would point at an absent identity, and" >&2
    echo "        every consumer aimed there would fail later and less clearly" >&2
    echo "      fix: attach an iam role to the instance, then re-apply" >&2
    return 1
  fi

  ####################################################################
  # 2. the block, fenced by its marker
  ####################################################################
  local cfg="$HOME/.aws/config"
  local marker='# grove: the ambient ec2 instance role, as a profile'
  local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

  mkdir -p "$HOME/.aws" || return 1
  touch "$cfg" || return 1

  ####################################################################
  # 3. rewrite in place — drop any prior fence, then write one
  #   - a plain append grows the file on every apply
  #   - a `grep -q` guard would skip a block whose CONTENTS changed
  ####################################################################
  # 🛑 the LEGACY fence — every box converged before 2026-09-02 carries it
  #   - the fence word moved `# devenv:` → `# grove:` at the suite cutover
  #   - this awk drops a prior fence BY THAT STRING, so a rename orphans it
  #   - ⇒ `~/.aws/config` would hold TWO `[profile ambient]` sections
  #   - ⇒ the last wins in the sdk, so the box works while no apply can see it
  #   - ⚠️ no accident saves this one, where `1.1.keybinds` and `1.2.power`
  #     also grep a CONTENT line the rename never touched
  local marker_was='# devenv: the ambient ec2 instance role, as a profile'

  local tmp
  tmp="$(mktemp)" || return 1

  awk -v m="$marker" -v mw="$marker_was" '
    $0 == m || $0 == mw { skip = 1; next }
    skip && /^# (grove|devenv): end$/ { skip = 0; next }
    !skip { print }
  ' "$cfg" > "$tmp" || { rm -f "$tmp"; return 1; }

  ####################################################################
  # ⚠️ a `[default]` block as well, with the SAME body
  #   - a consumer may legitimately drop AWS_PROFILE once keys are in env
  #   - that leaves the sdk with no profile, so the REGION goes with it:
  #
  #       ConfigError: Missing region in config
  #
  #   - 📜 grove-1 2026-08-06: 22 of 31 tests died there with valid credentials
  #   - a laptop never shows this, since its config carries a `[default]`
  #   - ⇒ `[default]` mirrors `ambient`, so a bare `aws sts` works with no flags
  #   - both sit inside one marker fence, so a re-run converges on both
  #   - (`rule.require.identical-commands-on-every-server`)
  ####################################################################
  {
    cat "$tmp"
    printf '%s\n' "$marker"
    printf '[profile ambient]\n'
    printf 'credential_source = Ec2InstanceMetadata\n'
    printf 'region = %s\n' "$region"
    printf '\n'
    printf '[default]\n'
    printf 'credential_source = Ec2InstanceMetadata\n'
    printf 'region = %s\n' "$region"
    printf '# grove: end\n'
  } > "$cfg" || { rm -f "$tmp"; return 1; }

  rm -f "$tmp"

  echo "   • the 'ambient' profile is declared ✔ (role: $role, region: $region)"
  echo "     .note = it names the instance role; it stores no credential"

  ####################################################################
  # 4. the EMPTY credentials file that `AWS_SDK_LOAD_CONFIG=1` demands
  #
  # ⚠️ an empty file is load-bear, never clutter
  #   - `src/zshrc.sh` exports `AWS_SDK_LOAD_CONFIG=1`, which routes v2's
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
  ####################################################################
  local creds="$HOME/.aws/credentials"
  if [[ -e "$creds" ]]; then
    echo "   • ~/.aws/credentials already present; left untouched ✔"
    return 0
  fi

  {
    printf '%s\n' '# grove: intentionally EMPTY.'
    printf '%s\n' '# aws-sdk v2 opens this file unconditionally when AWS_SDK_LOAD_CONFIG=1,'
    printf '%s\n' '# which src/zshrc.sh sets. an absent file throws ENOENT from Config.region.'
    printf '%s\n' '# this box has no key to store: its identity is ambient (the ec2 instance'
    printf '%s\n' '# role), declared as [profile ambient] in ~/.aws/config.'
  } > "$creds" || return 1
  chmod 600 "$creds" || return 1
  echo "   • ~/.aws/credentials created, EMPTY ✔ (aws-sdk v2 opens it unconditionally)"
}
