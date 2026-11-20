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

# .what = is this box a CAMP grove — the only place `aws.params` may be read or written
# 🛑 `rule.require.aws-params-on-camp-groves-only`. a camp grove carries the camp
#   account's aws identity BY MANDATE, on every platform: ec2 through its instance
#   role, hetzner through infra's IAM Roles Anywhere signer. `5.6.aws` ASSERTS that
#   identity first and fails loud where it is absent, so a reader here may rely on it
#   - a local or house grove has no such identity, so an `aws.params` write there
#     reads ssm as whatever credential the human's shell holds
# .why the TIER, never the platform — `cloud` is what a camp grove is; a platform
#   names only HOW the identity reaches the box. 📜 2026-11-15: an `*@aws.ec2` gate
#   here declined the fleet github token on a hetzner box whose role read it fine
grove_provision_5_12_rack_is_camp_grove() { [[ "${GROVE_ENV_SERVER:-}" == cloud@* ]]; }

# .what = the vault this seat's rack names for the github slug — empty if no entry
# .why a box provisioned before 2026-09-27 (#149) holds an `aws.params` entry off
#   ec2, which no unlock there can ever read; the heal and its verify both ask this
# exit: 0 = answered (empty is an answer) | 1 = the rack could not be read
grove_provision_5_12_rack_slug_vault_held() {
  local gitroot="$1" json
  # .why captured first — a failed list must not read as "no entry" (rule.forbid.failhide)
  json="$(env -C "$gitroot" rhx keyrack list \
            --owner "$(grove_provision_5_12_rack_slug_owner)" \
            --org "$(grove_provision_5_12_rack_slug_org)" \
            --env "$(grove_provision_5_12_rack_slug_env)" --json 2>/dev/null)" || return 1
  printf '%s' "$json" | jq -r --arg s \
    "$(grove_provision_5_12_rack_slug_org).$(grove_provision_5_12_rack_slug_env).$(grove_provision_5_12_rack_slug_key)" \
    '[.[] | select(.slug == $s) | .vault] | first // empty'
}

# .what = run a command with every route to an aws identity CUT
# 🛑 the stale-entry heal writes to a rack entry whose old vault is the fleet's
#   SHARED github token in ssm. keyrack's del reaches into the vault, and a human's
#   live sso session may hold creds for that account (ehmpathy/rhachet#697)
#   - ⇒ the writes run here, where the sdk's whole default chain finds naught:
#     env keys, profile, shared config + credentials files (and so sso), the
#     container endpoint, and imds
#   - the upsert PROVES the cut with an sts call before it writes
grove_provision_5_12_rack_without_aws() {
  env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE \
      -u AWS_ACCESS_KEY_ID -u AWS_SECRET_ACCESS_KEY -u AWS_SESSION_TOKEN \
      -u AWS_WEB_IDENTITY_TOKEN_FILE -u AWS_ROLE_ARN \
      -u AWS_CONTAINER_CREDENTIALS_FULL_URI -u AWS_CONTAINER_CREDENTIALS_RELATIVE_URI \
      AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null \
      AWS_EC2_METADATA_DISABLED=true \
      "$@"
}

# .what = retire a STALE `aws.params` github entry from a box that is not a camp grove
# .why
#   - until 2026-09-27 (#149) this bundle wrote the entry on EVERY box; the gate
#     that day stopped new writes and left the old ones in place
#   - off camp no unlock can read it, and rhachet fails the whole unlock on it
#   - 🛑 a bare `keyrack del` reaches into the vault, and that vault holds the
#     fleet's SHARED github token — so it either fails, or deletes it for every
#     grove (ehmpathy/rhachet#697 asks for a host-only del)
# .how
#   1. repoint the entry at `os.secure` with a placeholder — a LOCAL vault
#   2. del it, which now touches local storage only
#   - both run with every aws route cut, and the cut is PROVEN before either
# .when #697 ships a host-only del, step 1 goes and step 2 names `--scope host`
# .note = the upsert's one caller; it sits here beside `without_aws`, which it needs
grove_provision_5_12_rack_upsert_heal_stale() {
  local gitroot="$1" held owner key org env log
  owner="$(grove_provision_5_12_rack_slug_owner)"
  key="$(grove_provision_5_12_rack_slug_key)"
  org="$(grove_provision_5_12_rack_slug_org)"
  env="$(grove_provision_5_12_rack_slug_env)"

  # reject an unreadable rack — "could not read" is not "no entry"
  if ! held="$(grove_provision_5_12_rack_slug_vault_held "$gitroot")"; then
    echo "   ✋ could not read this seat's rack, so a stale ${org}.${env}.${key} is unread" >&2
    echo "      read why: rhx keyrack list --owner $owner --org $org --env $env" >&2
    return 1
  fi

  # no stale entry, no work
  if [[ "$held" != "aws.params" ]]; then
    echo "   • no stale aws.params entry for ${org}.${env}.${key} — no work"
    return 0
  fi

  # prove the cut BEFORE any write: an identity reachable here could reach the shared token
  if command -v aws >/dev/null 2>&1 \
     && grove_provision_5_12_rack_without_aws timeout -k 5 20 \
          aws sts get-caller-identity >/dev/null 2>&1; then
    echo "   ✋ an aws identity is reachable with every known route cut, so the heal is REFUSED" >&2
    echo "      ⇒ the stale ${org}.${env}.${key} entry points at the fleet's shared token," >&2
    echo "        and a del that reaches it would delete that token for every grove" >&2
    echo "      read why: rhx aws.whoami" >&2
    return 1
  fi

  # repoint at a local vault — the placeholder is piped, never in argv
  if ! log="$(printf 'placeholder-to-retire-a-stale-entry' \
        | grove_provision_5_12_rack_without_aws env -C "$gitroot" rhx keyrack set \
            --owner "$owner" --key "$key" --org "$org" --env "$env" \
            --vault os.secure --mech PERMANENT_VIA_REPLICA 2>&1)"; then
    echo "   ✋ could not repoint the stale ${org}.${env}.${key} at os.secure" >&2
    printf '%s\n' "$log" | sed 's/^/        /' >&2
    return 1
  fi

  # del — the entry now names a local vault, so this touches this box only
  if ! log="$(grove_provision_5_12_rack_without_aws env -C "$gitroot" rhx keyrack del \
        --owner "$owner" --key "$key" --org "$org" --env "$env" 2>&1)"; then
    echo "   ✋ repointed, but could not del ${org}.${env}.${key}" >&2
    echo "      ⇒ it now names os.secure, a LOCAL vault, so a del touches this box only" >&2
    echo "      ⇒ a rerun will NOT retry it: an os.secure entry may be a human's own" >&2
    echo "      fix: rhx keyrack del --owner $owner --org $org --env $env --key $key" >&2
    printf '%s\n' "$log" | sed 's/^/        /' >&2
    return 1
  fi
  echo "   • retired a stale aws.params entry for ${org}.${env}.${key} (the shared token untouched)"
}

# .what = the aws-profile slug, and the ONE value it ever holds
# .why
#   - it is gated on whether `ambient` ANSWERS (`aws configure export-credentials
#     --profile ambient`), never on the platform: an ec2 grove answers over imds,
#     a hetzner grove over infra's signer on loopback (`src/grove.aws.sh`), and a
#     laptop declines because it holds no `ambient` at all
#   - the vault is `os.direct`, which holds a name and is legal on every box;
#     `rule.require.aws-params-on-camp-groves-only` bounds only the `aws.params` vault
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

# .what = the ssm parameter name of this bundle's ONE aws.params slug — the
#   `_slug_*` github token — computed the same way keyrack computes it. no other
#   slug is addressed through it
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
#   .git by design — this names a throwaway empty dir instead, and
#   `configure.upsert`'s first step runs its `git init` (idempotent)
grove_provision_5_12_rack_gitroot() { printf '%s/.local/state/keyrack.gitroot' "$HOME"; }

# .what = declare ONE org in the scratch keyrack.yml
# 🛑 both halves call this, and each must call it per org before that org's slugs
#      are touched
#   - the file carries one `org:` line, so it declares one org at a time
#   - a NAMED-org read resolves against the yml IN SCOPE, so a read of org B
#     against org A's declaration answers EMPTY
#   - .refs = gotcha.5-12-rack.demo=entry-vs-value
grove_provision_5_12_rack_declare_org() {
  local gitroot="$1" org="$2" key e envs
  key="$(grove_provision_5_12_rack_awsprofile_key)"
  # an undeclared org refuses HERE, before the file is written — a `for` over the
  #   bare substitution would lose that rc and write `org:` with no envs
  if ! envs="$(grove_provision_5_12_rack_declared "$org")"; then
    echo "   ✋ ConstraintError: org '$org' has no declared rack table, and is not this grove's own (GROVE_ORG='${GROVE_ORG:-}')" >&2
    echo "      ⇒ a grove reaches its own org only (rule.require.a-grove-reaches-its-own-org-only)" >&2
    echo "      fix: declare the org's envs in grove_provision_5_12_rack_declared, in 5.12.rack/_.sh" >&2
    return 1
  fi
  mkdir -p "$gitroot/.agent" || return 1
  {
    printf '# .written by 5.12.rack — a scratch git root, NOT a checkout\n'
    printf '#   - the rhachet cli refuses a NAMED-org set unless a keyrack.yml\n'
    printf '#     is in scope, so this declares the minimum\n'
    printf '#   - REWRITTEN per org: one file declares one org\n'
    printf '#   - it declares MORE envs than this org sets, since a declaration\n'
    printf '#     is a legal name and not a value — see `_.sh`, `_declared`\n'
    printf 'org: %s\n' "$org"
    for e in $envs; do
      printf 'env.%s:\n' "$e"
      printf '  - %s\n' "$key"
    done
  } > "$gitroot/.agent/keyrack.yml"
}

grove_provision_5_12_rack() {
  bundle.upgrade 5.12.rack.configure.upsert
  bundle.upgrade 5.12.rack.configure.verify
}
