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

  # .the yardstick: this box's own badge. it is compared against, never printed
  ambient="$(aws sts get-caller-identity --profile ambient --query Account --output text 2>/dev/null)"
  [[ "$ambient" == 'None' ]] && ambient=''

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
    echo "      ⇒ ${verdict}" >&2
    # 🛑 the count is FIVE, and the fifth arrived 2026-09-07 with this bundle's
    #   first `EPHEMERAL_VIA_GITHUB_APP` row. it is the one state a PLACEMENT can
    #   never close — `git.grove.auth.keys.set` refuses such a row at step 0,
    #   because `get` MINTS its value rather than hand back what the rack stores,
    #   so a placement would seal a 55-minute corpse that reads green forever
    #
    #   ⇒ a fix-text that named four would send a human to `keyrack list` and an
    #     unlock, and neither touches that cause. a list of causes is a claim
    #     about a SET, and this set grew
    #     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11)
    echo "      ⇒ EMPTY collapses five states, and each wants a different repair:" >&2
    echo "         · this seat's \$HOME holds no manifest entry for the slug" >&2
    echo "         · the session lapsed" >&2
    echo "         · this box cannot read that vault" >&2
    echo "         · an aws.params value was written into a DIFFERENT account" >&2
    echo "         · the key MINTS its value (an ephemeral mech), so no replica" >&2
    echo "           can be placed from another box — set it HERE, at a terminal:" >&2
    echo "             rhx keyrack set --owner ${owner} --key ${key} --org ${org} --env ${env}" >&2
    echo "      ⇒ read the rack before you write to it — a set OVERWRITES:" >&2
    echo "         rhx keyrack list --owner ${owner}" >&2
    echo "         rhx keyrack unlock --owner ${owner} --env ${env}" >&2
  done

  [[ "$failed" -eq 0 ]] || return 1
  return 0
}
