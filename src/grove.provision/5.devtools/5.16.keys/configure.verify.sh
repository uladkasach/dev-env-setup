####################################################################
# .what = ask the rack for every required key, and fail if one is unreadable
#
# .why an EMPTY answer is the only signal the rack gives, and it collapses
#   FOUR states that want four different repairs (`term=entry`):
#
#     · this seat's $HOME holds no manifest entry for the slug
#     · the session lapsed
#     · this box cannot read that vault
#     · the param was written into a DIFFERENT aws account
#
#   ⇒ so the fix-text may never say "run keyrack set" — a set OVERWRITES the
#     live value, and on a piped stdin it stores an EMPTY one while it prints
#     `✔ set`. it names the four states and hands the human the read instead
#     (`rule.require.github-token-at-all-camp`, the four-state block)
#
# 🛑 it prints the ACCOUNT ALIGNMENT per org, because that is the one state a
#   human cannot guess from an empty answer. it prints `= ambient` /
#   `!= ambient`, never an account id — this repo is PUBLIC
#   (`rule.forbid.dox-in-public-repo`)
####################################################################

grove_provision_5_16_keys_configure_verify() {
  local owner gitroot ambient row org rest env key profile acct verdict got failed
  owner="$(grove_provision_5_16_keys_owner)"
  gitroot="$(grove_provision_5_12_rack_gitroot)"
  failed=0

  # ⚠️ the gitroot is `5.12.rack`'s, and that bundle creates it. a box where
  #   `5.12.rack` declined leaves this absent, and a named-org read from
  #   elsewhere throws — which would read as "the key is absent"
  if [[ ! -d "$gitroot" ]]; then
    echo "   🌙 no keyrack gitroot — 5.12.rack has not run here, so no key was asked for"
    return 0
  fi

  # 🛑 ZERO ROWS IS A STATE, and it may never read as a pass
  #   the rows are keyed on `GROVE_ORG`, so an org with no arm — and a run
  #   with no org at all — asks for no key and this loop runs zero times. that
  #   is CORRECT (`rule.require.a-grove-reaches-its-own-org-only`, clause 3)
  #   and it is not a ✔: a silent exit 0 claims the box can read its keys,
  #   while what happened is that none were checked (`rule.forbid.failhide`)
  #
  #   ⇒ 🌙, never ✔ and never ✋ — this bundle learned no fact about the rack
  if [[ -z "$(grove_provision_5_16_keys_required)" ]]; then
    if [[ -z "${GROVE_ORG:-}" ]]; then
      echo "   🌙 this run names no org, so no key row is owed — and none was read"
      grove_org_absent_say
      return 0
    fi
    echo "   🌙 no key row is declared for org '${GROVE_ORG}', so none was read"
    echo "      ⇒ an org with no table gets ZERO rows, never another org's"
    echo "        (rule.require.a-grove-reaches-its-own-org-only)"
    echo "      ⇒ if this grove's work DOES need vendor keys, add its arm:"
    echo "        src/grove.provision/5.devtools/5.16.keys/_.sh → \`_required\`"
    return 0
  fi

  # 🛑 .off the ec2 platform, a key lives in `os.secure` and NEVER in `aws.params`
  #   - a local or house grove has no ec2 identity to read ssm with
  #   - ⇒ the account-alignment yardstick below is void there, and a fix-text
  #     that named aws.params would send a human to write into whatever account
  #     their shell happened to hold (`rule.forbid.aws-params-off-ec2`)
  local onec2=0
  grove_provision_5_12_rack_platform_is_ec2 && onec2=1

  # .the yardstick: this box's own badge. it is compared against, never printed
  ambient=''
  if [[ "$onec2" -eq 1 ]]; then
    ambient="$(aws sts get-caller-identity --profile ambient --query Account --output text 2>/dev/null)"
    [[ "$ambient" == 'None' ]] && ambient=''
  fi

  for row in $(grove_provision_5_16_keys_required); do
    org="${row%%:*}"
    rest="${row#*:}"
    env="${rest%%:*}"
    key="${rest##*:}"

    # 🛑 halt a malformed row — `${rest##*:}` on a 2-field row hands back the
    #   ENV, so the read would ask for a key named after an env and answer
    #   empty, and the fix-text would blame a human for a table defect
    if [[ "$row" != *:*:* ]]; then
      echo "   ✋ the required row '${row}' is not '<org>:<env>:<key>'" >&2
      echo "      ⇒ see 5.16.keys/_.sh, \`_required\`" >&2
      return 1
    fi

    grove_provision_5_16_keys_declare "$gitroot" "$org" "$env" "$key" || return 1

    # .which account this org's params are addressed through
    profile="$(env -C "$gitroot" rhx keyrack get --owner "$owner" --key AWS_PROFILE \
                 --org "$org" --env "$env" --unlock --value 2>/dev/null)"
    acct=''
    [[ -n "$profile" ]] && acct="$(aws sts get-caller-identity --profile "$profile" \
                                     --query Account --output text 2>/dev/null)"
    if [[ -z "$profile" ]]; then
      verdict="no AWS_PROFILE — a named-org vault can address no account"
    elif [[ -z "$acct" || "$acct" == 'None' || -z "$ambient" ]]; then
      verdict="profile '${profile}' — account unread"
    elif [[ "$acct" == "$ambient" ]]; then
      verdict="profile '${profile}' = this box's ambient account"
    else
      verdict="profile '${profile}' != this box's ambient account"
    fi

    got="$(env -C "$gitroot" rhx keyrack get --owner "$owner" --key "$key" \
             --org "$org" --env "$env" --unlock --value 2>/dev/null)"

    if [[ -n "$got" ]]; then
      echo "   ✔ ${org}.${env}.${key} — the rack hands over a value"
      continue
    fi

    failed=1
    echo "   ✋ ${org}.${env}.${key} — the rack hands over an EMPTY value" >&2
    echo "      ⇒ this key is REQUIRED: every ${org} ${env} suite on this box dies without it" >&2

    # .off ec2, three states and one vault — see the header above the loop
    if [[ "$onec2" -eq 0 ]]; then
      echo "      ⇒ '${GROVE_ENV_SERVER:-unset}' has no ec2 identity, so this key lives in os.secure" >&2
      echo "      ⇒ EMPTY here means one of three:" >&2
      echo "         · the session lapsed" >&2
      echo "         · this seat's \$HOME holds no entry for the slug" >&2
      echo "         · an entry points at aws.params, which this box cannot read" >&2
      echo "      ⇒ read the rack before you write to it — a set OVERWRITES:" >&2
      echo "         rhx keyrack list --owner ${owner}" >&2
      echo "         rhx keyrack unlock --owner ${owner} --env ${env}" >&2
      echo "      ⇒ absent, or wired to aws.params? place it here, at a terminal, in os.secure:" >&2
      echo "         rhx keyrack set --owner ${owner} --key ${key} --org ${org} --env ${env} --vault os.secure" >&2
      echo "      🛑 never --vault aws.params on this box (rule.forbid.aws-params-off-ec2)" >&2
      continue
    fi

    echo "      ⇒ ${verdict}" >&2
    # 🛑 the count is FIVE, and the fifth arrived 2026-09-07 with this bundle's
    #   first `EPHEMERAL_VIA_GITHUB_APP` row. it is the one state a PLACEMENT can
    #   never close — `git.grove.auth.keys.set` refuses such a row at step 0,
    #   because `keyrack get` DELIVERS the minted token and never hands back the
    #   blob the rack stores, so a get→set pipe seals a 55-minute corpse that
    #   reads green forever (`ehmpathy/rhachet#522`)
    #
    #   ⇒ a fix-text that named four would send a human to `keyrack list` and an
    #     unlock, and neither touches that cause. a list of causes is a claim
    #     about a SET, and this set grew
    #     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11)
    #
    # 🛑 .the fifth row's REPAIR was wrong until 2026-09-28, and worse than the
    #   miss it replaced. it read "set it HERE, at a terminal" — printed by a
    #   bundle that runs ON A GROVE, where a tty read is a declared blocker
    #   (`rule.require.one-command-provision`). a human who obeyed it either
    #   wedged the duct with a prompt no one could answer, or broke the
    #   invariant to close a row.
    #   ⇒ a correct verdict whose repair is forbidden (m.4). the vault is what
    #     closes this, and it is written once on a LAPTOP — never on the box
    echo "      ⇒ EMPTY collapses five states, and each wants a different repair:" >&2
    echo "         · this seat's \$HOME holds no manifest entry for the slug" >&2
    echo "         · the session lapsed" >&2
    echo "         · this box cannot read that vault" >&2
    echo "         · an aws.params value was written into a DIFFERENT account" >&2
    echo "         · the key is an EPHEMERAL mech, so \`get\` hands back a minted" >&2
    echo "           token rather than the stored blob — and a replica placed" >&2
    echo "           from that is a corpse. ⚠️ do NOT 'set it here': this box is" >&2
    echo "           a grove, and a tty on the provision path is a blocker." >&2
    echo "           the repair is CENTRAL, run once on a human's own laptop —" >&2
    echo "             rhx keyrack set --owner ${owner} --key ${key} \\" >&2
    echo "               --org ${org} --env ${env} --vault aws.params" >&2
    echo "           thereafter every grove reads the blob and mints its own" >&2
    echo "           token, with no prompt on any box" >&2
    echo "      ⇒ read the rack before you write to it — a set OVERWRITES:" >&2
    echo "         rhx keyrack list --owner ${owner}" >&2
    echo "         rhx keyrack unlock --owner ${owner} --env ${env}" >&2
  done

  [[ "$failed" -eq 0 ]] || return 1
  return 0
}
