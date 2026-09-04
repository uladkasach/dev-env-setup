#!/usr/bin/env bash
# .what = give THIS seat's RACK the manifest entries a grove needs, so a
#   `keyrack get` can find values that already exist
# .why
#   - `keyrack` names the COMMAND (5.3.brains); this owns the STORAGE in
#     $HOME/.rhachet/keyrack/ — a box can hold one, not the other
#   - two per-$HOME MACHINE facts wanted by every repo: @all.camp.GITHUB_TOKEN
#     (aws.params) and ahbode.{test,prep}.AWS_PROFILE (os.direct, `ambient`)
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
#   - ONLY `camp` — `test`/`prep` need `rhx aws.reach.set --env <env>` instead
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
grove_provision_5_12_rack_awsprofile_key()   { printf 'AWS_PROFILE'; }
grove_provision_5_12_rack_awsprofile_org()   { printf 'ahbode'; }
grove_provision_5_12_rack_awsprofile_vault() { printf 'os.direct'; }
grove_provision_5_12_rack_awsprofile_value() { printf 'ambient'; }
grove_provision_5_12_rack_awsprofile_envs()  { printf 'camp'; }

# .what = the envs the scratch keyrack.yml DECLARES, a superset of what this
#   bundle SETS
# .why keyrack's cli refuses a named-org set unless declared, so `aws.reach.set
#   --env test` needs test/prep declared though this bundle sets camp alone
grove_provision_5_12_rack_awsprofile_envs_declared() { printf 'camp test prep'; }

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

grove_provision_5_12_rack() {
  bundle.upgrade 5.12.rack.configure.upsert
  bundle.upgrade 5.12.rack.configure.verify
}
