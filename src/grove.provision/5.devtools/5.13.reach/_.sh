#!/usr/bin/env bash
######################################################################
# .what = give this box an aws identity in every env its repos test against
#
# .why
#   - `5.6.aws` gives the box a camp badge; a suite targets test/prep/prod
#   - the camp role has no rights there, so every suite is AccessDenied
#   - a bundle drives the skill: a hand step is a forbidden fourth step
#
# .why derived, never typed
#   - infra renames these roles, so a recalled name is a guess
#   - a wrong role refuses exactly like an absent grant
#   - a wrong account assumes CLEANLY into elsewhere, with no error to read
#   - an account id in a tracked file is dox, and this repo is public
#
# .sources
#   | role    | ahbode/infrastructure → provision/aws.auth/resources.role-names.ts |
#   | account | any ahbode repo → declapract.use.yml → awsAccountId.<key>          |
#
# .note  = the rack's env and declapract's account key are two vocabularies, mapped
#          per row in `_envs` and never inferred from each other
# .order = after `5.10.repos`; both sources are clones
# .refs  = howdoes.a-box-reach-an-aws-account.md — every .why below, in full
# usage  = rhx grove.provision --what 5.13.reach --mode apply
######################################################################

# .what = the owner every keyrack call in this repo passes
grove_provision_5_13_reach_owner() { printf 'ehmpath'; }

# .what = the ONE org whose accounts this box reaches into
# ⚠️ a second org is a REWRITE, not a row — this returns a scalar
#   - every reader below takes it as one value: `_account` globs `~/git/<org>/`,
#     the upsert declares it once, the verify compares against it
#   - 📜 `5.12.rack` carried this same scalar and the same "just a row" comment,
#     and the second org cost a `<org>:<env>,<env>` table plus a loop in BOTH
#     of its halves — the comment promised cheap and the change was not
#   - ⇒ a second org here owes that AND a row in `5.12.rack`'s `_declared`,
#     since the scratch yml this bundle reads against is that bundle's
grove_provision_5_13_reach_org() { printf 'ahbode'; }

# .what = the envs to wire, as `<env>:<declapractKey>:<roleKey>`
# 🛑 every env here must ALSO sit in `5.12.rack`'s `_declared ahbode` — else the set
#      writes the profile body, then fails on the rack name. a half-applied pair
# .note = test borrows prep's account key; declapract retired `dev`
# .note = prod is reader by infra's design — a power role is a separate call
grove_provision_5_13_reach_envs() {
  printf 'test:prep:prepPower prep:prep:prepPower prod:prod:prodReader'
}

# .what = where the role names are declared
# .why  = a grep, not `node` — the file is a dependency-free constants module
grove_provision_5_13_reach_rolesrc() {
  printf '%s/git/ahbode/infrastructure/provision/aws.auth/resources.role-names.ts' "$HOME"
}

# .what = read the grove role name out of infrastructure's own declaration
# 🛑 anchor on GROVE_ROLE_NAME — the OIDC block above it holds the SAME keys, and
#      its `prodReader` differs by one segment, so a bare grep looks right
# .why = no default key: it would compose the prep role against the prod account
grove_provision_5_13_reach_role() {
  local src key
  src="$(grove_provision_5_13_reach_rolesrc)"
  key="${1:-}"
  [[ -n "$key" ]] || return 2
  [[ -f "$src" ]] || return 1

  # take the GROVE_ROLE_NAME block only, then the key within it
  sed -n '/export const GROVE_ROLE_NAME/,/^} as const;/p' "$src" \
    | grep -m1 -E "^[[:space:]]*${key}:" \
    | sed -E "s/.*'([^']+)'.*/\1/"
}

# .what = read an org's account id for one declapract key, across every clone
#         that declares it, and demand they AGREE
# 🛑 .why a first-match read is unsafe, however true the premise
#   - the glob spans EVERY clone under `~/git/<org>/`, all writable
#   - the winner is whatever `sort` puts first, so `aaa-repo` outranks infra
#   - the value becomes a `role_arn` this box then assumes into
#   - ⇒ one altered file redirects which ACCOUNT is reached, and says so nowhere
#   - so a disagreement halts and names the files, rather than pick a winner
#   - same shape as the grove trust anchor's (`git.grove.trust.gen`)
# .why exactly 12 digits, not `{6,}` = an aws account id IS twelve digits, and
#      a malformed one composes a `role_arn` that reads as an infra defect
# .note = never echoed — it is dox, and this repo is public
grove_provision_5_13_reach_account() {
  local key="$1"
  local org repo found="" found_in="" seen="" conflicts=""
  org="$(grove_provision_5_13_reach_org)"

  for repo in "$HOME/git/$org"/*/declapract.use.yml; do
    [[ -f "$repo" ]] || continue
    # 🛑 .why awk and never a `sed` range
    #   - the block boundary is INDENTATION, which a sed range cannot express
    #   - three keys carry `dev`/`prep`/`prod`, so a bare grep reads a hostname
    #   - a range closes on its OWN first child, so every other key reads empty
    #   - and it fails SOFTLY: the verify reads an unreadable account as 🌙
    seen="$(awk -v key="$key" '
      /^[[:space:]]*awsAccountId:[[:space:]]*$/ { inblock = 1; base = match($0, /[^ ]/); next }
      inblock {
        ind = match($0, /[^ ]/)
        if (ind <= base) { inblock = 0; next }
        if ($1 == key ":" && $2 ~ /^[0-9]{12}$/) { print $2; exit }
      }
    ' "$repo" | grep -m1 -oE '^[0-9]{12}$')" || seen=""
    [[ -n "$seen" ]] || continue

    if [[ -z "$found" ]]; then
      found="$seen"
      found_in="$repo"
    elif [[ "$seen" != "$found" ]]; then
      conflicts="$conflicts$repo"$'\n'
    fi
  done

  # a DISAGREEMENT is a security event, never a tie to break — see the header
  if [[ -n "$conflicts" ]]; then
    echo "   ✋ clones under ~/git/$org disagree on awsAccountId.$key" >&2
    echo "      first read:  $found_in" >&2
    echo "      it disagrees with:" >&2
    printf '%s' "$conflicts" | sed 's/^/        /' >&2
    echo "      ⇒ this id becomes a role_arn in ~/.aws/config, so a box that" >&2
    echo "        picked the wrong one reaches the wrong ACCOUNT and says so" >&2
    echo "        nowhere. no value is returned until they agree." >&2
    echo "      fix: read each file above and correct the one that drifted —" >&2
    echo "        git -C \"\$(dirname <file>)\" status" >&2
    return 1
  fi

  [[ -n "$found" ]] || return 1
  printf '%s\n' "$found"
}

grove_provision_5_13_reach() {
  bundle.upgrade 5.13.reach.configure.upsert
  bundle.upgrade 5.13.reach.configure.verify
}
