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

# .what = the aws-profile slug, and the ONE value it ever holds
# .why
#   - every grove is ec2, so IMDS always answers `5.6.aws`'s `ambient` role
#   - no secret is stored: `ambient` names an identity, and an instance
#     role's keys rotate on aws's clock, so a stored copy would go stale
#   - ONLY `camp`. every other env is a REACH — a hop out of camp into another
#     account — so its value is a per-env profile name and not `ambient`, and
#     `5.13.reach` sets it by drive of `rhx aws.reach.set --env <env>`
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
grove_provision_5_12_rack_awsprofile_key()   { printf 'AWS_PROFILE'; }
grove_provision_5_12_rack_awsprofile_vault() { printf 'os.direct'; }
grove_provision_5_12_rack_awsprofile_value() { printf 'ambient'; }

# .what = the orgs whose AWS_PROFILE is the box's own badge, as `<org>:<env>,<env>`
# 🛑 the env sets DIFFER on purpose, and neither may hold the other's
#   - `5.13.reach` overwrites ahbode's test/prep/prod with per-account profile
#     names, so to list them here is two writers on one slug
#   - ehmpathy's envs hold `ambient` because no hop is DECLARED for them yet:
#     no ehmpathy repo declares an `awsAccountId`, and `GROVE_ROLE_NAME` holds
#     two keys, both `ahbode-*`
#   - ⚠️ that is a fact about what is READABLE, never about what EXISTS in aws.
#     ehmpathy holds its own accounts; the grant and the declaration are owed
#     (uladkasach/dev-env-setup#123). do NOT restate the absence as "no account
#     exists" — that claim stood here until 2026-09-06 and was wrong
#   - ⇒ the rows STAY until the hop replaces them: `ambient` is what lets
#     `keyrack.source()` read the ssm params those suites need
grove_provision_5_12_rack_awsprofile_rows() {
  printf 'ahbode:camp ehmpathy:test,prep,prod'
}

# .what = per org, the envs the scratch keyrack.yml DECLARES — a superset of its row
# .why keyrack's cli refuses a named-org set unless declared
# 🛑 this must hold every env `5.13.reach` wires for that org, else its set writes
#      the profile body and then fails on the rack name — a half-applied pair
#      (one fact, two holders: `gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
grove_provision_5_12_rack_declared() {
  case "$1" in
    ahbode)   printf 'camp test prep prod' ;;
    ehmpathy) printf 'test prep prod' ;;
    *)        return 1 ;;
  esac
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
#   - 📜 measured: after the upsert's loop left `ehmpathy` declared, the verify
#     called a present `ahbode.camp` entry absent, and named a fix that would
#     have re-run the same loop forever
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
