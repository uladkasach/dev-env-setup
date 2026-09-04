#!/usr/bin/env bash
######################################################################
# .what = prove that, for each declared env, the rack NAMES a profile and that
#         profile ANSWERS in the account the tree declares
#
# ⚠️ it re-asks what the upsert already proved
#   - the upsert's proof was about the moment it ran
#   - a plan is the one read that tells a human a box is converged, unchanged
#   - ⇒ a plan that skipped this would call a box fine while every suite fails
#
# ⚠️ it checks the ACCOUNT, never merely that a call succeeds
#   - a profile pointed at the wrong account assumes CLEANLY and answers happily
#   - ⇒ only the account in the returned identity tells the two apart
#   - ⇒ that is why `aws.reach.set` refuses a recalled `--account`
#
# 🛑 the account is COMPARED, never printed
#   - this repo is PUBLIC and a duct keeps scrollback
#   - ⇒ a mismatch reports "not the declared account" and quotes no id
#   - (`rule.forbid.dox-in-public-repo`)
#
# guarantee:
#   - read-only: one sts call and one rack read per env, and no write
#   - it declines where the reach cannot apply, and FAILS where it should hold
######################################################################

grove_provision_5_13_reach_configure_verify() {
  local org owner
  org="$(grove_provision_5_13_reach_org)"
  owner="$(grove_provision_5_13_reach_owner)"

  if ! aws configure export-credentials --profile ambient >/dev/null 2>&1; then
    echo "   • declined — no ambient identity here, so no reach to prove"
    return 0
  fi

  if ! command -v rhx >/dev/null 2>&1; then
    echo "   • declined — rhx is absent, so the rack cannot be read (5.3.brains)"
    return 0
  fi

  ####################################################################
  # ⚠️ a NAMED org's rack read is CWD-SENSITIVE, so it runs where the write did
  #   - 📜 `5.12.rack` measured one box one second apart: `ambient` from the
  #     scratch root, EMPTY from this checkout
  #   - a named org reads against a `keyrack.yml` IN SCOPE
  #   - ⇒ an empty answer here would mean the wrong cwd, never an absent entry
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"

  local failed=0 pair env dkey account named seen
  for pair in $(grove_provision_5_13_reach_envs); do
    env="${pair%%:*}"
    dkey="${pair##*:}"

    # 1. does the rack NAME a profile for this env?
    named="$(env -C "$gitroot" rhx keyrack get --owner "$owner" --key AWS_PROFILE \
               --org "$org" --env "$env" --unlock --value 2>/dev/null | tail -1)"

    if [[ -z "$named" ]]; then
      echo "   ✋ the rack names no profile for ${org}.${env}.AWS_PROFILE" >&2
      echo "      ⇒ every suite that targets ${env} dies at 'AWS_PROFILE not set.'" >&2
      echo "        with live credentials one metadata call away" >&2
      echo "      fix: rhx grove.provision --what 5.13.reach --mode apply" >&2
      failed=1
      continue
    fi

    # 2. does that profile ANSWER, and from the account the tree declares?
    seen="$(aws sts get-caller-identity --profile "$named" \
              --query Account --output text 2>/dev/null)"

    if [[ -z "$seen" || "$seen" == "None" ]]; then
      echo "   ✋ the rack names '${named}' for ${org}.${env}, and it does not answer" >&2
      echo "      ⇒ a named profile with no live body is a profile aws cannot find" >&2
      echo "        — the half-applied pair aws.reach.set exists to prevent" >&2
      echo "      ⇒ read the refusal in full:" >&2
      echo "        aws sts get-caller-identity --profile ${named}" >&2
      echo "      fix: rhx grove.provision --what 5.13.reach --mode apply" >&2
      failed=1
      continue
    fi

    account="$(grove_provision_5_13_reach_account "$dkey")"
    if [[ -z "$account" ]]; then
      echo "   🌙 ${org}.${env} answers as '${named}', and no clone declares the"
      echo "      account to compare it against — so the ACCOUNT half is unproven"
      echo "      ⇒ this is a weaker ✔ on purpose: the call answers, and whether"
      echo "        it lands in the right account cannot be judged with no tree"
      continue
    fi

    if [[ "$seen" != "$account" ]]; then
      echo "   ✋ '${named}' answers from an account the tree does not declare" >&2
      echo "      ⇒ neither id is printed: this repo is public and a duct keeps" >&2
      echo "        scrollback (rule.forbid.dox-in-public-repo)" >&2
      echo "      ⇒ this is the SILENT failure the derivation exists to stop — the" >&2
      echo "        profile assumed cleanly, and into somewhere else. every suite" >&2
      echo "        on it will fail on permissions, far from this cause" >&2
      echo "      ⇒ compare them by hand:" >&2
      echo "        aws sts get-caller-identity --profile ${named} --query Account" >&2
      echo "        grep -A4 awsAccountId ~/git/${org}/*/declapract.use.yml" >&2
      failed=1
      continue
    fi

    echo "   ✔ ${org}.${env} answers as '${named}', in the declared account"
  done

  return $failed
}
