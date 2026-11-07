#!/usr/bin/env bash
######################################################################
# .what = declare the `ambient` aws profile on a cloud grove — the one
#         that names the box's OWN ec2 instance role
#
# .an ec2 grove already HAS an identity, and could not say so
#   - an EC2 grove answers IMDS — and ONLY an ec2 grove. a local, house, or
#     hetzner grove has no instance role (`rule.forbid.aws-params-off-ec2`)
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
# 🏠 a house seat takes its own branch — `_upsert_house`, below
#   - its badge is a Roles Anywhere cert on disk, so what it owes here is the
#     0700 badge dir and the timer that renews the cert
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
  # a house seat has no instance role; its badge is a cert on disk
  if [[ "${GROVE_ENV_SERVER:-}" == house@* ]]; then
    grove_provision_5_6_aws_configure_upsert_house
    return
  fi

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
  ####################################################################
  grove_provision_5_6_aws_credentials_findsert 'the ec2 instance role'
}

# .what = findsert the EMPTY `~/.aws/credentials` that aws-sdk v2 opens unconditionally
# .why one writer for both box kinds; only the line that names the badge differs
grove_provision_5_6_aws_credentials_findsert() {
  local badge="$1" creds="$HOME/.aws/credentials"
  if [[ -e "$creds" ]]; then
    echo "   • ~/.aws/credentials already present; left untouched ✔"
    return 0
  fi

  {
    printf '%s\n' '# grove: intentionally EMPTY.'
    printf '%s\n' '# aws-sdk v2 opens this file unconditionally when AWS_SDK_LOAD_CONFIG=1,'
    printf '%s\n' '# which 2.shell/2.5.zsh/zshrc.sh sets. an absent file throws ENOENT from Config.region.'
    printf '# this box has no key to store: its identity is ambient (%s),\n' "$badge"
    printf '%s\n' '# declared as [profile ambient] in ~/.aws/config.'
  } > "$creds" || return 1
  chmod 600 "$creds" || return 1
  echo "   • ~/.aws/credentials created, EMPTY ✔ (aws-sdk v2 opens it unconditionally)"
}

######################################################################
# .what = a house seat's half: the badge dir at 0700, and the renewal timer armed
#
# .why a house seat's badge is a 7-day cert on disk (F6), so the one live part is
#   its renewal. the timer is a USER unit: it renews this seat's own cert as this
#   seat, and needs no sudo
#
# 🛑 it writes no cert and no key. the first cert is the mint's to place, from
#   the host, since a seat cannot vouch for itself to a CA it holds no badge for
#
# guarantee:
#   - idempotent: a converged seat reads ✔ and writes naught
#   - the dir is tightened every run, never loosened
######################################################################
grove_provision_5_6_aws_configure_upsert_house() {
  local dir unit_dir name timer_src
  dir="$(grove_provision_5_6_aws_house_dir)"
  unit_dir="$(grove_provision_5_6_aws_house_unit_dir)"
  name="$(grove_provision_5_6_aws_house_renew_name)"
  timer_src="$GROVE_SRC/grove.provision/5.devtools/5.6.aws/$name.timer"

  # the badge dir, 0700 — the per-uid wall the cert and key sit behind
  mkdir -p "$dir" && chmod 700 "$dir" || return 1
  echo "   • $dir is 0700 ✔"

  grove_provision_5_6_aws_credentials_findsert 'a house seat'"'"'s Roles Anywhere cert' || return 1

  # what is already true — read before any write
  local converged=1
  cmp -s "$timer_src" "$unit_dir/$name.timer" || converged=0
  grove_provision_5_6_aws_house_service_text | cmp -s - "$unit_dir/$name.service" || converged=0
  systemctl --user is-enabled "$name.timer" >/dev/null 2>&1 || converged=0
  systemctl --user is-active  "$name.timer" >/dev/null 2>&1 || converged=0
  if [[ "$converged" -eq 1 ]]; then
    echo "   • the renewal units match this checkout, and the timer is armed ✔"
    return 0
  fi

  mkdir -p "$unit_dir" || return 1
  grove_provision_5_6_aws_house_service_text > "$unit_dir/$name.service" || return 1
  cp "$timer_src" "$unit_dir/$name.timer" || return 1
  echo "   • $name.service and $name.timer declared"

  # reload FIRST — a rewrite with no reload leaves the old definition live
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ a house seat's user manager needs linger, since no desktop holds it up" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 1.6.5.usermanager --mode apply   (from the host)" >&2
    return 1
  }
  systemctl --user enable --now "$name.timer" || {
    echo "   ✋ could not enable $name.timer — the cert would lapse in 7 days, unrenewed" >&2
    return 1
  }
  echo "   • $name.timer enabled (hourly; renews below $GROVE_PROVISION_5_6_AWS_HOUSE_RENEW_AT_HOURS hours left)"
}
