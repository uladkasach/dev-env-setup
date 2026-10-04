#!/usr/bin/env bash
# .what = give THIS seat's RACK the manifest entries a grove needs, so a
#   `keyrack get` can find values that already exist
# .why
#   - `keyrack` names the COMMAND (5.3.brains); this owns the STORAGE in
#     $HOME/.rhachet/keyrack/ — a box can hold one, not the other
#   - two per-$HOME MACHINE facts wanted by every repo: @all.camp.GITHUB_TOKEN
#     (aws.params) and AWS_PROFILE = `ambient` (os.direct), per org × env
#   - a value in a central vault is NOT a readable credential — a fresh seat
#     has no HOST MANIFEST entry, so this writes the entry, never a secret
#     (term=entry, rule.forbid.repair-plays)
#   - the upsert is idempotent: it hands the CURRENT ssm value back unchanged
#   - order: AFTER 5.6.aws, BEFORE 5.4.gh, carried by 5.devtools/_.sh
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
#
# usage:
#   rhx grove.provision --what 5.12.rack --mode plan
#   rhx grove.provision --what 5.12.rack --mode apply

# .what = the owner every keyrack call in this repo passes
grove_provision_5_12_rack_slug_owner() { printf 'ehmpath'; }

# .what = the github slug, spelled as every consumer reads it
# .why an invented coordinate is the defect to stop (rule.require.github-token-at-all-camp)
grove_provision_5_12_rack_slug_key()   { printf 'GITHUB_TOKEN'; }
grove_provision_5_12_rack_slug_org()   { printf '@all'; }
grove_provision_5_12_rack_slug_env()   { printf 'camp'; }
grove_provision_5_12_rack_slug_vault() { printf 'aws.params'; }

# .what = is this box on the ec2 PLATFORM — the only place `aws.params` may be written
# 🛑 `rule.forbid.aws-params-off-ec2`. a local or house grove has no ec2 identity,
#   so an `aws.params` write there reads ssm as whatever credential the human's
#   shell holds, rewires the entry, and PUTs the value back into that account
# .why the PLATFORM half of the tag, never the tier — `cloud` names who reaches the
#   box, `aws.ec2` names the fact this depends on, and any tag this repo does not
#   know yet (a house grove) fails CLOSED
grove_provision_5_12_rack_platform_is_ec2() { [[ "${GROVE_ENV_SERVER:-}" == *@aws.ec2 ]]; }

# .what = the aws-profile slug, and the ONE value it ever holds
# .why
#   - every CLOUD grove is ec2 for now, so IMDS answers `5.6.aws`'s `ambient`
#     role there. a local or house grove has no ec2 identity, so this slug
#     declines on it (`rule.forbid.aws-params-off-ec2`)
#   - no secret is stored: `ambient` names an identity, and an instance
#     role's keys rotate on aws's clock, so a stored copy would go stale
#   - ONLY `camp`. every other env is a REACH — a hop out of camp into another
#     account — so its value is a per-env profile name and not `ambient`, and
#     `5.13.reach` sets it by drive of `rhx aws.reach.set --env <env>`
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
grove_provision_5_12_rack_awsprofile_key()   { printf 'AWS_PROFILE'; }
grove_provision_5_12_rack_awsprofile_vault() { printf 'os.direct'; }
grove_provision_5_12_rack_awsprofile_value() { printf 'ambient'; }

# .what = the orgs whose AWS_PROFILE is the box's own badge, as `<org>:<env>`
# 🔴 the rows are PER-ORG, and the camp row is DERIVED, never listed
#   - `<org>:camp` is the box's OWN BADGE; every OTHER row is a CROSS-ORG reach,
#     an opt-in owned by the org that granted it
#     (`rule.require.a-grove-reaches-its-own-org-only`)
#   - 🛑 an org with no opt-in table gets its camp row and NO OTHER. it does not
#     inherit ahbode's, however convenient that would be
#   - an env `5.13.reach` wires may NOT appear here — that is two writers on one
#     slug. a row stays only until a real hop replaces it
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
grove_provision_5_12_rack_awsprofile_rows() {
  local org="${GROVE_ORG:-}"
  [[ -n "$org" ]] || return 0

  # clause 1 — the box's own badge, for its own org, always
  printf '%s:camp' "$org"

  # clause 2 — the cross-org opt-ins, per org that holds one
  # ⚠️ ehmpathy is a CANDIDATE only because it is generic infra. that ahbode
  #   opted in says not one word about any other org
  case "$org" in
    ahbode) printf ' ehmpathy:prod' ;;
  esac
}

# .what = per org, the envs the scratch keyrack.yml DECLARES — a superset of its row
# .why keyrack's cli refuses a named-org set unless declared
# 🛑 this must hold every env `5.13.reach` wires for that org, else its set writes
#      the profile body and then fails on the rack name — a half-applied pair
#      (one fact, two holders: `gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# 🔴 `camp` is granted by DERIVATION, so a NEW org needs no edit here to hold its
#      own badge — only to wire a REACH, which it must then match
#   - 🛑 an org that is neither this grove's own nor a declared opt-in target
#     still REFUSES (`rule.require.a-grove-reaches-its-own-org-only`, clause 3)
grove_provision_5_12_rack_declared() {
  local want="$1" own="${GROVE_ORG:-}" envs=""

  case "$want" in
    ahbode)   envs='test prep prod' ;;
    # ⚠️ `test` and `prep` are declared for `5.13.reach`'s two ehmpathy rows, and
    #   for no row of THIS bundle — both are deliberately absent from
    #   `_awsprofile_rows` above, since that would be two writers on one slug. a
    #   declaration is a legal NAME and never a value, so a declared-but-unset
    #   env costs one line
    # 🛑 `demo` is NOT declared: it names the ACCOUNT, never a tier, and keyrack's
    #   own `KEYRACK_VALID_ENVS` holds no such value — so a row wired that way
    #   writes the profile body and then refuses the rack name
    ehmpathy) envs='test prep prod' ;;
    # aether's OWN reach — the three envs `5.13.reach`'s aether arm wires
    aether)   envs='test prep prod' ;;
    # 🛑 clause 3 — an org with no declared table gets no env, and the caller
    #   halts. it does NOT fall through to whichever table is written here
    *)        [[ "$want" == "$own" && -n "$own" ]] || return 1 ;;
  esac

  # the own-org camp badge, prepended for ANY org this grove belongs to
  if [[ "$want" == "$own" && -n "$own" ]]; then
    printf 'camp%s' "${envs:+ $envs}"
    return 0
  fi

  printf '%s' "$envs"
}

# .what = the ssm parameter name, computed the same way keyrack computes it
# .why reproduces keyrack's own contract, so read and write address the same
#   parameter; substitutes `_all_` for `@all`, outside ssm's charset
grove_provision_5_12_rack_param_name() {
  local org
  org="$(grove_provision_5_12_rack_slug_org)"
  [[ "$org" == "@all" ]] && org="_all_"
  printf '/keyrack/infra/vault/aws.params/v1/%s/%s/%s/%s' \
    "$(grove_provision_5_12_rack_slug_owner)" \
    "$org" \
    "$(grove_provision_5_12_rack_slug_env)" \
    "$(grove_provision_5_12_rack_slug_key)"
}

# .what = a directory that IS a git repo, for keyrack's cli to run from
# .why rhachet's cli calls getGitRepoRoot first, and a pushed checkout has no
#   .git by design — this names a throwaway empty `git init` dir instead
grove_provision_5_12_rack_gitroot() { printf '%s/.local/state/keyrack.gitroot' "$HOME"; }

# .what = declare ONE org in the scratch keyrack.yml
# 🛑 both halves call this, and each must call it per org before that org's slugs
#      are touched
#   - the file carries one `org:` line, so it declares one org at a time
#   - a NAMED-org read resolves against the yml IN SCOPE, so a read of org B
#     against org A's declaration answers EMPTY
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
grove_provision_5_12_rack_declare_org() {
  local gitroot="$1" org="$2" key e
  key="$(grove_provision_5_12_rack_awsprofile_key)"
  mkdir -p "$gitroot/.agent" || return 1
  {
    printf '# .written by 5.12.rack — a scratch git root, NOT a checkout\n'
    printf '#   - the rhachet cli refuses a NAMED-org set unless a keyrack.yml\n'
    printf '#     is in scope, so this declares the minimum\n'
    printf '#   - REWRITTEN per org: one file declares one org\n'
    printf '#   - it declares MORE envs than this org sets, since a declaration\n'
    printf '#     is a legal name and not a value — see `_.sh`, `_declared`\n'
    printf 'org: %s\n' "$org"
    for e in $(grove_provision_5_12_rack_declared "$org"); do
      printf 'env.%s:\n' "$e"
      printf '  - %s\n' "$key"
    done
  } > "$gitroot/.agent/keyrack.yml"
}

grove_provision_5_12_rack() {
  bundle.upgrade 5.12.rack.configure.upsert
  bundle.upgrade 5.12.rack.configure.verify
}
