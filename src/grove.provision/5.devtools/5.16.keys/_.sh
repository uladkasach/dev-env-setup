####################################################################
# .what = the keys a box MUST be able to READ from its rack, and the
#         verify that asks the rack for each one
#
# .why = every other bundle here converges something it OWNS. this one owns no
#   artifact — a vendor api key is a human's to place. what it owns is the
#   CLAIM that the box can read them, which no other bundle asserts:
#
#     5.12.rack  writes the two slugs THIS REPO owns (AWS_PROFILE, GITHUB_TOKEN)
#     5.13.reach writes the per-account profiles those reads hop through
#     5.16.keys  asks the rack for every key a SUITE needs, and reports
#
#   ⇒ so a grove could be fully converged, every bundle green, and still fail
#     its first suite at `FIREWORKS_API_KEY is not set` — because "the key is
#     SET" and "the key is READABLE HERE" are two facts (`term=entry`).
#
# 🛑 .why it runs LAST
#   - a named-org read is addressed through that org's `AWS_PROFILE`, which
#     `5.12.rack` names and `5.13.reach` fills in for a hopped env
#   - ⇒ to ask before those land is to measure a box mid-provision and blame
#     the human for a key that was fine
#
# 🛑 it PRINTS no secret — a value is reported as held/empty, never echoed
#   (`rule.forbid.dox-in-public-repo`)
####################################################################

# .what = the owner every keyrack call in this repo passes
grove_provision_5_16_keys_owner() { printf 'ehmpath'; }

# .what = the keys a box must be able to read, as `<org>:<env>:<key>`
#
# 🛑 a row here is a HARD REQUIREMENT — the box fails its verify without it.
#   add a row when a suite cannot run without that key on a fresh grove.
#
# 🛑 .a row here says the box must READ it — it says none of HOW it gets there
#   a grove has two sources, and the row is silent about which serves it:
#
#     `aws.params`  central, and PER ACCOUNT. a NAMED-org param is addressed
#                   through THAT ORG's `AWS_PROFILE`, and on a grove ehmpathy's
#                   is `ambient` — the CAMP badge. so a value the laptop wrote
#                   into the ehmpathy account is read from camp's, and answers
#                   EMPTY. that is uladkasach/dev-env-setup#123
#     `os.secure`   a REPLICA on the box, sealed to that box's own recipients.
#                   no aws grant reaches it, and `git.grove.auth.keys.set`
#                   PLACES one from a box that already holds the value
#
#   ⇒ so a row blocked on #123 is NOT blocked on a human: the placement seals a
#     replica and the read goes green. the cost is that a rotation must be
#     re-placed per box, which is what that skill's `--refresh` is for.
#
# ⚠️ 📜 measured 2026-09-06 on grove-ahbode-v20260901, and it is why the account
#   line sits in this bundle's verify at all:
#
#     ehmpathy: profile 'ambient'             -> = this box's ambient account
#     ahbode:   profile 'ahbode.test.ehmpath' -> != this box's ambient account
#     ✋ ehmpathy.test.FIREWORKS_API_KEY — EMPTY
#     ✔ ehmpathy.prep.FIREWORKS_API_KEY — held
# ✔ .the ORG axis is settled — the human, 2026-09-07
#
#   > *"the roles will still need the orgs version of ahbode.prep.FIREWORKS_API_KEY"*
#
#   ⇒ a role composes its slug under the org of the TREE IT RUNS IN, never the org
#     its own manifest pins. so `ehmpathy/role=mechanic` declares FIREWORKS, and
#     inside `ahbode/svc-chat` that resolves to `ahbode.prep.FIREWORKS_API_KEY`.
#
#   ⇒ **so a vendor key is per-ORG, not per-vendor.** one fireworks account may
#     back every row, and each org still needs its own ENTRY, because the org is
#     an axis of the address (`term=slug`) and — under `aws.params` — of the
#     ACCOUNT the read authenticates into (`term=entry`, the fifth cause).
#
# ⚠️ .the rows are named by the HUMAN, and a DERIVATION is what checks them
#
#   the manifests say which keys a role declares:
#
#     bhrain/reviewer    env.prep  FIREWORKS_API_KEY
#     ehmpathy/mechanic  env.prep  FIREWORKS_API_KEY   env.test  FIREWORKS_API_KEY
#     bhrain ROOT        env.test  OPENAI · ANTHROPIC · TAVILY · XAI · FIREWORKS
#
# 🛑 📜 and a DERIVATION FROM THEM WAS WRONG, 2026-09-07 — the record stays, because
#   the reasoning was plausible and will re-occur. this block read:
#
#     "FIREWORKS is the ONLY vendor key any enrolled role declares. bhrain's ROOT
#      manifest adds OPENAI/ANTHROPIC/TAVILY/XAI at env.test, and those are read
#      only by work INSIDE the bhrain repo — a grove that clones svc-chat never asks"
#
#   the human asked for all four to be placed. ⇒ **a grove is not only a box that
#   runs svc-chat's suite; it is a box that does BHRAIN work too** — a review, a
#   route guard, a reviewer brain. those read the bhrain root manifest's keys.
#
#   ⇒ the defect was to derive the CONSUMER SET from one workload I had watched,
#     then state it as a property of the box. a manifest says what a role declares;
#     it says none of which trees a grove will be asked to work in.
#
# ⇒ so the rule is: **a human names the rows; the manifests are what a reader CHECKS
#   them against.** a row here that no manifest declares is worth a question. a
#   manifest key that no row carries is NOT automatically a missing row — it depends
#   on the workload, and only a human knows that.
#
# ✔ .the ORG SCOPE is settled — the human, 2026-09-07: **ahbode and ehmpathy only**
#
#   this box's rack holds five owners; three of them carry no row here on purpose.
#   ⇒ so `nheuron`, `whodis`, and `whodisio` are ABSENT BY DECISION, not by oversight,
#     and a reader who "completes the set" from the rack would widen a scope a human
#     narrowed. to add one is a question for a human, exactly as the rule above says
grove_provision_5_16_keys_required() {
  printf 'ahbode:prep:FIREWORKS_API_KEY ehmpathy:prep:FIREWORKS_API_KEY'
  printf ' ahbode:test:FIREWORKS_API_KEY ehmpathy:test:FIREWORKS_API_KEY'
  # the bhrain root manifest's vendor set, at env.test — asked for 2026-09-07
  printf ' ehmpathy:test:OPENAI_API_KEY ehmpathy:test:ANTHROPIC_API_KEY'
  printf ' ehmpathy:test:TAVILY_API_KEY ehmpathy:test:XAI_API_KEY'
  # the radio's robot identity — `radio.task.pull` pins env=prep and this key, and
  # takes the ORG from the checkout it runs in (`getGithubTokenByAuthArg.js:40-49`)
  #
  # 🛑 this row can NOT be PLACED, and that is a property of its MECHANISM, not
  #   a gap in the box. it is `EPHEMERAL_VIA_GITHUB_APP`, so a `get` MINTS a
  #   55-minute token rather than hand back what the rack stores — a placement
  #   would seal a corpse that reads green forever. `git.grove.auth.keys.set`
  #   refuses it at step 0 and prints the duct-pane `keyrack set` instead
  #
  # ⚠️ so these two rows are the ONLY ones a fresh grove cannot converge unattended,
  #   and that is an UPSTREAM gap rather than a defect here: the stored source has
  #   no read path and no write path (`vaultAdapterOsSecure.js:144` and `:193`).
  #   the ask is `ehmpathy/rhachet#522` — until it lands, a human types the pem on
  #   each box, once per org
  printf ' ahbode:prep:EHMPATH_BEAVER_GITHUB_TOKEN'
  printf ' ehmpathy:prep:EHMPATH_BEAVER_GITHUB_TOKEN'
}

# .what = declare ONE org, plus the ONE key about to be read, in the scratch yml
#
# 🛑 this does NOT reuse `5.12.rack`'s `declare_org` — that one declares only
#   `AWS_PROFILE`, and keyrack refuses a named-org read of a key the yml in
#   scope does not name. so this writes the same file with the key added.
#   - ⚠️ it therefore LEAVES a declaration `5.12.rack` did not write. that is
#     safe only because this bundle runs LAST and `5.12.rack` re-declares per
#     org before each of its own reads — never lean on the file's prior state
#   - `AWS_PROFILE` rides along because the named-org read needs it to address
#     an account at all
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
