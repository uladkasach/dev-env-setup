####################################################################
# .what = the keys a box MUST be able to READ from its rack
#
# .why
#   - a vendor api key is a human's to place, so this owns no artifact
#   - what it owns is the CLAIM that the box can READ them
#   - "SET" and "READABLE HERE" are two facts (`term=entry`)
#   - ⇒ a grove can be all-green and still die on its first suite
#   - 🛑 it runs LAST: a named-org read is addressed through the `AWS_PROFILE`
#     that `5.12.rack` names and `5.13.reach` fills in for a hopped env
#   - 🛑 it PRINTS no secret — held/empty, never the value
#     (`rule.forbid.dox-in-public-repo`)
#
# 📜 the measurements behind every clause above:
#   `briefs/grove/provision/gotcha.5-16-keys.demo=rows-are-named-by-a-human.md`
####################################################################

# .what = the owner every keyrack call in this repo passes
grove_provision_5_16_keys_owner() { printf 'ehmpath'; }

# .what = the keys a box must be able to read, as `<org>:<env>:<key>`
# 🛑 a row is a HARD REQUIREMENT — the box fails its verify without it
# 🛑 a human NAMES the rows; the manifests are what a reader CHECKS them
#   against. a row no manifest declares is worth a question; a manifest key
#   no row carries is not automatically an absent row — only a human knows
#   the workload. 📜 a derivation from the manifests was WRONG once
# 🛑 the ORG SCOPE is ahbode + ehmpathy (the human, 2026-09-07), plus aether
#   for OPENROUTER_API_KEY alone (the human, 2026-10-04). every other owner on
#   the rack is ABSENT BY DECISION
#
# 🔴 the rows are PER-ORG, and an unknown org gets ZERO — a key row is a claim
#   about WORK, and the work belongs to an org
#   (`rule.require.a-grove-reaches-its-own-org-only`)
grove_provision_5_16_keys_required() {
  local org="${GROVE_ORG:-}"
  [[ -n "$org" ]] || return 0

  case "$org" in
    ahbode)
      printf 'ahbode:prep:FIREWORKS_API_KEY ahbode:test:FIREWORKS_API_KEY'
      printf ' ahbode:prep:OPENROUTER_API_KEY ahbode:test:OPENROUTER_API_KEY'

      # ⚠️ the ehmpathy rows ride AHBODE's opt-in, exactly as `5.13.reach`'s
      #   do — ehmpathy is generic infra, and ahbode opted into it. no other
      #   org inherits them
      printf ' ehmpathy:prep:FIREWORKS_API_KEY ehmpathy:test:FIREWORKS_API_KEY'
      printf ' ehmpathy:prep:OPENROUTER_API_KEY ehmpathy:test:OPENROUTER_API_KEY'

      # the bhrain root manifest's vendor set, at env.test — asked for 2026-09-07
      printf ' ehmpathy:test:OPENAI_API_KEY ehmpathy:test:ANTHROPIC_API_KEY'
      printf ' ehmpathy:test:TAVILY_API_KEY ehmpathy:test:XAI_API_KEY'

      # the radio's robot identity — `radio.task.pull` pins env=prep and this key,
      # and takes the ORG from the checkout (`getGithubTokenByAuthArg.js:40-49`)
      #
      # 🛑 these two cannot ride `git.grove.auth.keys.set`: `keyrack get` DELIVERS the
      #   minted token and never the stored blob, so a get→set pipe seals a corpse
      #   that reads green forever (`ehmpathy/rhachet#522`)
      # 🛑 the remedy is a VAULT, never a terminal on the box — `aws.params` holds
      #   this mech, so it is written ONCE on a laptop and every grove mints its own
      #   token with no prompt (`rule.require.one-command-provision`)
      printf ' ahbode:prep:EHMPATH_BEAVER_GITHUB_TOKEN'
      printf ' ehmpathy:prep:EHMPATH_BEAVER_GITHUB_TOKEN'
      ;;
    aether)
      # asked for 2026-10-04 — OPENROUTER alone; aether's other vendor keys are not rows
      printf 'aether:prep:OPENROUTER_API_KEY aether:test:OPENROUTER_API_KEY'
      ;;
    # 🛑 clause 3 — no arm, no rows. a row is a HARD REQUIREMENT, so a
    #   fallback here fails a box's verify over another org's workload
    *) return 0 ;;
  esac
}

# .what = declare ONE org, plus the ONE key about to be read, in the scratch yml
# 🛑 NOT `5.12.rack`'s `declare_org` — that declares only `AWS_PROFILE`, and
#   keyrack refuses a named-org read of a key the yml in scope omits. so this
#   LEAVES a declaration `5.12.rack` did not write, safe ONLY because this runs
#   last and that bundle re-declares per org before each of its own reads
grove_provision_5_16_keys_declare() {
  local gitroot="$1" org="$2" env="$3" key="$4"
  mkdir -p "$gitroot/.agent" || return 1
  {
    printf '# .written by 5.16.keys — a scratch git root, NOT a checkout\n'
    printf '#   - one org, one env, one key: the minimum a named-org read needs\n'
    printf '#   - REWRITTEN per row\n'
    printf 'org: %s\n' "$org"
    printf 'env.%s:\n' "$env"
    printf '  - %s\n' "$key"
    printf '  - AWS_PROFILE\n'
  } | tee "$gitroot/.agent/keyrack.yml" >/dev/null
}

grove_provision_5_16_keys() {
  bundle.upgrade 5.16.keys.configure.verify
}
