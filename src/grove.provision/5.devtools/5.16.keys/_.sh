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
# 🛑 the ORG SCOPE is ahbode + ehmpathy ONLY (the human, 2026-09-07). this
#   box's rack holds five owners; the other three are ABSENT BY DECISION
grove_provision_5_16_keys_required() {
  printf 'ahbode:prep:FIREWORKS_API_KEY ehmpathy:prep:FIREWORKS_API_KEY'
  printf ' ahbode:test:FIREWORKS_API_KEY ehmpathy:test:FIREWORKS_API_KEY'
  # the bhrain root manifest's vendor set, at env.test — asked for 2026-09-07
  printf ' ehmpathy:test:OPENAI_API_KEY ehmpathy:test:ANTHROPIC_API_KEY'
  printf ' ehmpathy:test:TAVILY_API_KEY ehmpathy:test:XAI_API_KEY'

  # the radio's robot identity — `radio.task.pull` pins env=prep and this key,
  # and takes the ORG from the checkout (`getGithubTokenByAuthArg.js:40-49`)
  # 🛑 these two can NOT be PLACED: `EPHEMERAL_VIA_GITHUB_APP` MINTS its value,
  #   so a replica seals a 55-minute corpse that reads green forever — the ONLY
  #   rows a fresh grove cannot converge unattended (`ehmpathy/rhachet#522`)
  printf ' ahbode:prep:EHMPATH_BEAVER_GITHUB_TOKEN'
  printf ' ehmpathy:prep:EHMPATH_BEAVER_GITHUB_TOKEN'
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
