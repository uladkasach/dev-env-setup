#!/usr/bin/env bash
######################################################################
# .what = give this box an aws identity in every env its repos test against
#
# .why
#   - `5.6.aws` gives the box a camp badge; a suite targets dev/prep
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
# .note  = declapract says `dev` where the rack says `test` — one account, two
#          vocabularies, stated and never inferred
# .order = after `5.10.repos`; both sources are clones
# .refs  = howdoes.a-box-reach-an-aws-account.md — every .why below, in full
# usage  = rhx grove.provision --what 5.13.reach --mode apply
######################################################################

# .what = the owner every keyrack call in this repo passes
grove_provision_5_13_reach_owner() { printf 'ehmpath'; }

# .what = the org whose accounts this box reaches into
# .why  = the shape is per-org already, so a second org is a row, not a rewrite
grove_provision_5_13_reach_org() { printf 'ahbode'; }

# .what = the envs to wire, and the declapract key each reads its account from
# .why `prod` is ABSENT
#   - a different account and a different tier
#   - `GROVE_ROLE_NAME` offers only `prodReader` there
#   - to wire it widens this box's blast radius for an unasked capability
#   - a human who wants it runs `--env prod`: a grant, not a convergence
grove_provision_5_13_reach_envs() { printf 'test:dev prep:prep'; }

# .what = where the role names are declared
# .why  = a grep, not `node` — the file is a dependency-free constants module
grove_provision_5_13_reach_rolesrc() {
  printf '%s/git/ahbode/infrastructure/provision/aws.auth/resources.role-names.ts' "$HOME"
}

# .what = the GROVE_ROLE_NAME key each env's role is declared under
# .why  = test and prep are one account and one tier; the split that made these
#         roles exist is per-TIER, not per-env
grove_provision_5_13_reach_rolekey() { printf 'prepPower'; }

# .what = read the grove role name out of infrastructure's own declaration
# 🛑 .why it anchors on GROVE_ROLE_NAME, never OIDC_ROLE_NAME
#   - both blocks sit in one file and both hold a `prepPower` key
#   - `OIDC_ROLE_NAME` is declared ABOVE it, so a bare key grep takes it first
#   - that role trusts an OIDC principal, so it rejects this box
# .why ONE file, where `..._reach_account` demands agreement across all
#   - there is exactly ONE `infrastructure` clone per box
#   - the value is clamped by `reach_clamp --assume`, which excludes newline
#   - a profile is a convenience, never a boundary
#   - the account id has neither, which is why IT gets the agreement check
grove_provision_5_13_reach_role() {
  local src key
  src="$(grove_provision_5_13_reach_rolesrc)"
  key="${1:-$(grove_provision_5_13_reach_rolekey)}"
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
