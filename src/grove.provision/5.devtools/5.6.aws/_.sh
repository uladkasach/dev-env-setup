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

######################################################################
# 🏠 .the house badge — what a house seat's `ambient` must be, and the files it reads
#
# .why a house seat has no IMDS. its badge is IAM Roles Anywhere, reached by
#   `aws_signing_helper credential-process`: the sdk calls it per session, it signs
#   from a cert + key on disk, and it opens no port and runs no daemon (F6).
#   the cert is short-lived, so a user timer renews it a day before its end (case=7)
#
# 🛑 every reader below is PURE: a path in, one word out, no aws call. so the
#   verify, the renewal, and the hermetic clamp (`grove.house.test`) ask the same
#   function, and a clamp can feed it a fixture
######################################################################

# .what = where a house seat holds its badge, declared ONCE
# .why the upsert, the verify, the renewal unit, and the clamp all read these;
#   the dir is 0700 and each file 0600, which is the whole per-uid wall (F6, F15)
grove_provision_5_6_aws_house_dir()  { printf '%s/.aws/house' "$HOME"; }
grove_provision_5_6_aws_house_cert() { printf '%s/badge.crt' "$(grove_provision_5_6_aws_house_dir)"; }
grove_provision_5_6_aws_house_key()  { printf '%s/badge.key' "$(grove_provision_5_6_aws_house_dir)"; }

# .what = renew once fewer hours than this are left; and the verify refuses below it
# .why the cert lives 7 days (AWS Private CA short-lived mode). a renewal due at one
#   day left, and a verify that refuses at one day left, means a failed renewal is
#   loud for a whole day before the badge dies — never at the hour it does
GROVE_PROVISION_5_6_AWS_HOUSE_RENEW_AT_HOURS=24

# .what = the renewal's user units, and the service text this checkout renders
# .why the service names the checkout path it runs from, so it is RENDERED, never
#   copied: one reader feeds the write and the verify's `cmp`, and a moved
#   checkout reads as drift rather than as a timer that fails each hour
grove_provision_5_6_aws_house_unit_dir()     { printf '%s/.config/systemd/user' "$HOME"; }
grove_provision_5_6_aws_house_renew_name()   { printf 'house.badge.renew'; }
grove_provision_5_6_aws_house_renew_exec()   { printf '%s/grove.provision/5.devtools/5.6.aws/house.badge.renew.sh' "$GROVE_SRC"; }
grove_provision_5_6_aws_house_service_text() {
  local tpl="$GROVE_SRC/grove.provision/5.devtools/5.6.aws/house.badge.renew.service"
  awk -v exec="$(grove_provision_5_6_aws_house_renew_exec)" '{ gsub(/@RENEW_EXEC@/, exec); print }' "$tpl"
}

# .what = the `key=value` lines of one section of an aws config, trimmed
# .why the aws cli is not asked: a reader that needs the cli cannot run in a
#   hermetic clamp, and `aws configure get` hides which keys sit side by side
grove_provision_5_6_aws_config_section() {
  local cfg="$1" section="$2"
  [[ -r "$cfg" ]] || return 1
  awk -v want="[$section]" '
    /^[[:space:]]*[#;]/ { next }
    /^[[:space:]]*\[/ {
      s = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); inside = (s == want); next
    }
    inside && /=/ {
      k = $0; sub(/=.*/, "", k);       gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      v = $0; sub(/^[^=]*=/, "", v);   gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      print k "=" v
    }
  ' "$cfg"
}

# .what = which SOURCE does this profile draw its credentials from?
#
# stdout, one word:
#   process         `credential_process` that runs `aws_signing_helper credential-process`
#   process_foreign `credential_process` that runs aught else (a `serve` or `update`
#                   helper, or a command nobody here wrote)
#   serve           an imds endpoint override — on a house seat that is a 127.0.0.1
#                   `serve` port, which every uid on the box can read (row 27)
#   instance_role   `credential_source = Ec2InstanceMetadata`
#   static_key      an `aws_access_key_id` in the profile (row 28)
#   sso             an sso session or start url (row 28)
#   hop             a `source_profile` / `role_arn` — a reach, never a badge
#   mixed           two or more of the above, side by side (a fallback is a second
#                   identity — vision case=4)
#   absent          no such profile, or no source in it
grove_provision_5_6_aws_badge_shape() {
  local cfg="$1" section="$2" body="" shapes=() cproc=""
  body="$(grove_provision_5_6_aws_config_section "$cfg" "$section")" || { echo absent; return 0; }

  # .what = the value of one key in the section body, or naught
  __badge_val() { printf '%s\n' "$body" | awk -v k="$1" -F= '$1 == k { sub(/^[^=]*=/, ""); print; exit }'; }

  cproc="$(__badge_val credential_process)"
  if [[ -n "$cproc" ]]; then
    if [[ "$cproc" =~ (^|[[:space:]/])aws_signing_helper[[:space:]]+credential-process([[:space:]]|$) ]]; then
      shapes+=(process)
    else
      shapes+=(process_foreign)
    fi
  fi
  [[ -n "$(__badge_val ec2_metadata_service_endpoint)" ]] && shapes+=(serve)
  [[ "$(__badge_val credential_source)" == Ec2InstanceMetadata ]] && shapes+=(instance_role)
  [[ -n "$(__badge_val aws_access_key_id)$(__badge_val aws_secret_access_key)" ]] && shapes+=(static_key)
  [[ -n "$(__badge_val sso_session)$(__badge_val sso_start_url)" ]] && shapes+=(sso)
  [[ -n "$(__badge_val source_profile)$(__badge_val role_arn)" ]] && shapes+=(hop)
  unset -f __badge_val

  case "${#shapes[@]}" in
    0) echo absent ;;
    1) echo "${shapes[0]}" ;;
    *) echo mixed ;;
  esac
}

# .what = whole hours until a cert's notAfter, negative once past; `?` if unreadable
# .why `?` is a third answer on purpose: a cert openssl cannot parse must never
#   read as a cert with time left (`rule.forbid.failhide`)
# .note = the second arg is the epoch to measure from, so a clamp can ask how a
#   cert reads a week from now without a fake clock
grove_provision_5_6_aws_cert_hours_left() {
  local cert="$1" now="${2:-}" end="" endsec=""
  command -v openssl >/dev/null 2>&1 || { echo '?'; return 0; }
  [[ -r "$cert" ]] || { echo '?'; return 0; }
  end="$(openssl x509 -noout -enddate -in "$cert" 2>/dev/null)" || { echo '?'; return 0; }
  end="${end#notAfter=}"
  endsec="$(date -u -d "$end" +%s 2>/dev/null)" || { echo '?'; return 0; }
  [[ -n "$now" ]] || now="$(date -u +%s)"
  echo $(( (endsec - now) / 3600 ))
}

# .what = is a badge file held to the per-uid wall?
#
# stdout: tight | wide | foreign | absent | ?
#   tight   owned by this uid, mode 0600 or 0400, in a dir of mode 0700
#   wide    any group or other bit on the file, or a dir that is not 0700 (row 24)
#   foreign owned by another uid — this seat cannot vouch for it
# .why the file modes ARE the boundary between two house groves on one box and
#   between a seat and the human's own login (rows 25, 26). a widened key is a
#   key every uid can sign as, so the verify reads the mode as a fact, every run
grove_provision_5_6_aws_badge_file_state() {
  local f="$1" owner="" mode="" dmode=""
  [[ -e "$f" ]] || { echo absent; return 0; }
  read -r owner mode < <(stat -c '%u %a' "$f" 2>/dev/null) || { echo '?'; return 0; }
  dmode="$(stat -c '%a' "$(dirname "$f")" 2>/dev/null)" || { echo '?'; return 0; }
  [[ "$owner" == "$(id -u)" ]] || { echo foreign; return 0; }
  [[ ( "$mode" == 600 || "$mode" == 400 ) && "$dmode" == 700 ]] || { echo wide; return 0; }
  echo tight
}

grove_provision_5_6_aws() {
  bundle.upgrade 5.6.aws.provision.upsert
  bundle.upgrade 5.6.aws.provision.verify
  bundle.upgrade 5.6.aws.configure.upsert
  bundle.upgrade 5.6.aws.configure.verify
}
