#!/usr/bin/env bash
######################################################################
# .what = prove this seat can actually READ the box's github token
#
# ⚠️ it reads the VALUE, never the manifest
#   - a manifest entry is what the upsert WROTE, and already said
#   - ⇒ the claim worth a proof is that a `get` returns bytes on THIS seat
#   - 📜 for two days the value was central and live, and every consumer
#     answered `absent 🫧` — a manifest-shaped check would call that healthy
#   - (`term=entry`, `rule.forbid.failhide`)
#
# 🛑 the value is never printed, echoed, or logged, only byte-counted
#   - this repo is PUBLIC, and a duct keeps scrollback
#   - (`rule.forbid.dox-in-public-repo`)
#
# guarantee:
#   - read-only: it unlocks into the daemon, and writes no machine state
#   - it declines where the slug cannot apply, and FAILS where it should hold
######################################################################

grove_provision_5_12_rack_configure_verify() {
  local key org env
  key="$(grove_provision_5_12_rack_slug_key)"
  org="$(grove_provision_5_12_rack_slug_org)"
  env="$(grove_provision_5_12_rack_slug_env)"

  if ! command -v rhx >/dev/null 2>&1; then
    echo "   • declined — rhx is absent, so the rack cannot be read (5.3.brains)"
    return 0
  fi

  ####################################################################
  # .the read, exactly as `5.4.gh` and `git-credential-keyrack` make it
  #
  # ⚠️ `--unlock` and `--allow-dangerous` are both REQUIRED, never stylistic
  #   - without `--unlock` a locked key returns an empty string and exit 0
  #   - without `--allow-dangerous` keyrack refuses a classic pat via a replica
  #   - ⇒ this must match `5.4.gh`, or a green here means less than a consumer's
  #
  # 🛑 `env -C "$gitroot"` — the CWD decides whether this read can load at all
  #   - rhachet loads `.agent/keyrack.yml` from the CWD before the org sigil
  #   - a cwd whose manifest `extends` an unvendored file THROWS
  #   - ⇒ `2>/dev/null` makes that 0 bytes, indistinguishable from an absence
  #   - 📜 2026-08-15 on a grove, from a pane whose cwd was an org checkout:
  #
  #      ✋ the rack returned 0 bytes for @all.camp.GITHUB_TOKEN
  #
  #   - ⇒ the consumer answered a real token on that box in that minute
  #   - ⇒ the rack was healthy, and the check halted the smoketest at rung 4
  #   - ⇒ every SIBLING call owes this guarantee, never the one that taught it
  #   - (`term=keyrack.gitroot`, `gotcha.a-check-that-cries-wolf-gets-silenced`,
  #      `define.provision-defect-shapes`, `.the NINTH shape`)
  ####################################################################
  local bytes gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"
  bytes="$(env -C "$gitroot" rhx keyrack get \
             --owner "$(grove_provision_5_12_rack_slug_owner)" \
             --key "$key" --org "$org" --env "$env" \
             --unlock --allow-dangerous --value 2>/dev/null | wc -c)"

  # .a classic pat is 40 chars, and the bar is deliberately LOW at >= 20
  #   - this phase's claim is that a value comes back
  #   - ⇒ the SHAPE of the credential is phase 2's business
  #   - (`grove.auth.github.roadmap.md`)
  if [[ "$bytes" -lt 20 ]]; then
    echo "   ✋ the rack returned $bytes bytes for ${org}.${env}.${key}" >&2
    echo "      ⇒ every github reach fails on auth until this returns a value: the" >&2
    echo "        org clone, the issue read, the pr open" >&2
    echo "      ⇒ the four causes behind one 'absent' — see term=entry:" >&2
    echo "        1. no manifest entry in THIS \$HOME   → this bundle's own upsert" >&2
    echo "        2. the read path rejects the org sigil → a keyrack defect" >&2
    echo "        3. the value is genuinely gone         → a human mints a pat once" >&2
    echo "        4. this box lacks the iam grant        → the role, not the rack" >&2
    echo "      ⇒ separate 1 from 3 and 4 in one command:" >&2
    echo "        aws ssm get-parameter --with-decryption --name \\" >&2
    echo "          $(grove_provision_5_12_rack_param_name) \\" >&2
    echo "          --query Parameter.Value --output text | wc -c" >&2
    echo "        bytes back   → cause 1, so re-run this bundle's apply" >&2
    echo "        AccessDenied → cause 4" >&2
    echo "        not found    → cause 3" >&2
    return 1
  fi

  echo "   ✔ the rack returns a value for ${org}.${env}.${key} on this seat"

  grove_provision_5_12_rack_verify_awsprofile
}

######################################################################
# .what = prove this seat can read the NAME of its ambient aws identity
#
# ⚠️ this value IS printed, where the github one never is
#   - a pat is a secret, so it is byte-counted and never shown
#   - `ambient` is a PROFILE NAME, and it grants no access
#   - ⇒ to mask a name buys no safety and costs this row its only diagnostic
#   - (`rule.forbid.dox-in-public-repo`)
######################################################################
grove_provision_5_12_rack_verify_awsprofile() {
  local key org owner want
  key="$(grove_provision_5_12_rack_awsprofile_key)"
  org="$(grove_provision_5_12_rack_awsprofile_org)"
  owner="$(grove_provision_5_12_rack_slug_owner)"
  want="$(grove_provision_5_12_rack_awsprofile_value)"

  # .a box with no ambient identity was correctly DECLINED by the upsert
  #   - ⇒ a failure here would be a false ✋ against a seat that did right
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  if ! aws configure export-credentials --profile "$want" >/dev/null 2>&1; then
    echo "   • declined — no ambient identity here, so no name to prove"
    return 0
  fi

  ####################################################################
  # ⚠️ the READ is cwd-sensitive for a NAMED org, exactly as the write is
  #   - 📜 2026-08-10, one box, one second apart: this get returned `ambient`
  #     from the bundle's scratch root and EMPTY from the dev-env-setup checkout
  #   - `keyrack list` showed the entry both times, so the manifest is no cause
  #   - a named-org lookup reads a `keyrack.yml` IN SCOPE, which declares `env.camp`
  #   - ⇒ an empty answer means the wrong cwd, a false ✋ on a converged box
  #   - ⇒ the read runs from the root the write used, so the two ask one question
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  #
  # ⚠️ stderr is NOT muted
  #   - 📜 one muted run hid the whole diagnosis behind an empty string
  #   - (`rule.forbid.failhide`)
  ####################################################################
  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"

  local env got
  for env in $(grove_provision_5_12_rack_awsprofile_envs); do
    got="$(env -C "$gitroot" rhx keyrack get --owner "$owner" --key "$key" \
             --org "$org" --env "$env" --unlock --value 2>/dev/null)"

    if [[ "$got" != "$want" ]]; then
      echo "   ✋ the rack returns '${got:-<empty>}' for ${org}.${env}.${key}, wanted '${want}'" >&2
      echo "      ⇒ every ahbode integration suite on this box dies at" >&2
      echo "        'AWS_PROFILE not set. keyrack.source() should have set it.'" >&2
      echo "        — with live ambient credentials one metadata call away" >&2
      echo "      ⇒ an EMPTY answer means the manifest holds no such entry, which" >&2
      echo "        this bundle's own upsert writes" >&2
      echo "      ⇒ a DIFFERENT answer means another writer claimed the slug; read" >&2
      echo "        it, since a wrong profile fails on permissions much later:" >&2
      echo "        rhx keyrack list --owner $owner" >&2
      echo "      fix: rhx grove.provision --what 5.12.rack --mode apply" >&2
      return 1
    fi
    echo "   ✔ the rack returns '${want}' for ${org}.${env}.${key} on this seat"
  done
}
