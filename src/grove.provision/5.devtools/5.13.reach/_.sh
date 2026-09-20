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

# 🛑 .the TWO orgs a row has, and they are not the same axis
#
#   | axis            | what it names                              | where it lives |
#   |-----------------|--------------------------------------------|----------------|
#   | the SOURCE org  | whose clones DECLARE the role + account id | `_srcorg`      |
#   | the TARGET org  | whose account the profile REACHES into     | the row        |
#
#   - they agreed for every row until 2026-09-13, so one scalar spelled both
#   - ⇒ then a grove needed reach into an EHMPATHY account, by a role that
#     `ahbode/infrastructure` declares — because infra is what CREATES the
#     cross-account role, whatever account it points at
#   - a scalar cannot hold that: the account must be read from ahbode's clones
#     while the profile is NAMED `ehmpathy.<env>.<owner>`
#
# ⚠️ 📜 this IS the rewrite the prior comment warned of, and its estimate held
#   - it said a second org costs "a table plus a loop in BOTH halves", citing
#     `5.12.rack`'s own precedent — and that is exactly what it cost
#   - ⇒ the warning was correct and is now spent. it is kept as a record
#     rather than a live caution (`rule.require.timeless-lessons`)

# .what = the ONE org whose CLONES declare the role names and account ids
# .why a scalar is still right HERE = it is paired with `_rolesrc`, which names
#      one file in one repo. a second declaring org owes a second source path,
#      so the two move together or neither does
grove_provision_5_13_reach_srcorg() { printf 'ahbode'; }

# .what = the rows to wire, as `<org>:<env>:<reader>:<accountKey>:<roleKey>`
#
# 🛑 `<org>` is the TARGET org — it names the profile and the rack entry, and it
#      says not one word about where the declaration is read from (that is `_srcorg`)
# 🛑 every `<org>:<env>` here must ALSO sit in `5.12.rack`'s `_declared <org>` — else
#      the set writes the profile body, then fails on the rack name. a half-applied pair
# .note = test borrows prep's account key; declapract retired `dev`
# .note = prod is reader by infra's design — a power role is a separate call
#
# 🛑 .why ehmpathy's test AND prep are ONE account, and `demo` is no env here
#   - `demo` names the ACCOUNT, never a tier. ehmpathy holds one non-prod
#     account and both of its non-prod tiers land in it
#   - measured in `ehmpathy/sdk-aws-lambda`: `.github/workflows/test.yml` and
#     `publish.yml` both oidc into that one account, and its `.agent/keyrack.yml`
#     declares `env.prep: [AWS_PROFILE]` — so the slug a suite READS is
#     `ehmpathy.prep.AWS_PROFILE`, never `ehmpathy.demo.*`
#   - ⇒ two rows, one account key. a row per TIER is what a consumer selects by
#   - 📜 a `demo` row was wired first and died at its own callee: keyrack's
#     `KEYRACK_VALID_ENVS` holds no such value, so the profile body landed and
#     the rack name refused — the half-applied pair this file warns of above.
#     the enum was the SIGNAL, never the defect: `demo` was the wrong axis
#
# 🛑 .the `<reader>` field, and why one declaration source was not enough
#   - `declmap` — the two MAPS every ahbode reach is declared in: the account from
#     a clone's `declapract.use.yml` under `awsAccountId:`, the role from
#     `GROVE_ROLE_NAME` in `resources.role-names.ts`
#   - `arnconst` — a PAIR OF PLAIN CONSTS beside the arn builder, in
#     `resources.reach-arns.ts`
#   - ⇒ the row NAMES its reader, and no reader falls back to the other. a
#     fallback would read a typo'd key as "the other source's job" and decline
#     with a reason that names the wrong repo (`rule.forbid.failhide`)
#
# 🛑 .why the two ehmpathy rows CANNOT use `declmap`, and it is by infra's design
#   - `GROVE_ROLE_NAME`'s keys are TIER-shaped — `prepPower`, `prodReader` — so an
#     org-shaped `ehmpathyDemo` key would cross the axes inside the map itself
#   - infra's own fulcrum rules that a name it does NOT OWN may not sit in a slot
#     whose contract claims source-of-truth, so the demo pair sits beside the arn
#     builder instead, as `ACCOUNT_ID_EHMPATHY_DEMO` + `DEMO_POWER_ROLE_NAME`
#   - 📜 measured 2026-09-14 against `ahbode/infrastructure`'s reach branch: a
#     grep for `ehmpathyDemo` across that tree returns ONE hit, and it is the
#     fulcrum line that forbids the key. this row read that key for a day, so its
#     decline said "not readable HERE" for a name that will never be readable
#     ANYWHERE (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
grove_provision_5_13_reach_envs() {
  printf 'ahbode:test:declmap:prep:prepPower ahbode:prep:declmap:prep:prepPower ahbode:prod:declmap:prod:prodReader ehmpathy:test:arnconst:ACCOUNT_ID_EHMPATHY_DEMO:DEMO_POWER_ROLE_NAME ehmpathy:prep:arnconst:ACCOUNT_ID_EHMPATHY_DEMO:DEMO_POWER_ROLE_NAME'
}

# .what = where the `declmap` reader finds the role-name map
# .why  = a grep, not `node` — the file is a dependency-free constants module
grove_provision_5_13_reach_rolesrc() {
  printf '%s/git/ahbode/infrastructure/provision/aws.auth/resources.role-names.ts' "$HOME"
}

# .what = where the `arnconst` reader finds its pair of plain consts
# .why  = infra holds a foreign-owned account id and role name beside the arn that
#         composes them, rather than in either declared map — see `_envs` above
grove_provision_5_13_reach_arnsrc() {
  printf '%s/git/ahbode/infrastructure/provision/aws.auth/resources.reach-arns.ts' "$HOME"
}

# .what = read one `export const <KEY> = '<value>' as const;` out of a ts module
# .why  = both halves of an `arnconst` row share this one shape, so they share one
#         reader — two copies of a regex is two places for it to drift
# 🛑 anchored at column 0 on `export const`, so a mention inside a comment or a
#      doc block cannot answer. a commented-out const is not a declaration
grove_provision_5_13_reach_tsconst() {
  local src="$1" key="${2:-}"
  [[ -n "$key" ]] || return 2
  [[ -f "$src" ]] || return 1

  grep -m1 -E "^export const ${key}[[:space:]]*=" "$src" \
    | sed -E "s/.*'([^']+)'.*/\1/"
}

# .what = name, for a human, WHERE a reader's declarations live
# .why  = the upsert and the verify decline with this same sentence, so it gets
#         ONE holder — two copies name two files, and only one of them is right
#         (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
# 🛑 a decline that names the WRONG file is the defect this exists to stop
#   - the demo row read a `GROVE_ROLE_NAME` key for a day, and its decline said
#     "not readable here" for a name infra's own fulcrum FORBIDS in that map
#   - ⇒ it asked a reader to fix a file that will never carry the answer (m.4)
grove_provision_5_13_reach_declsrc() {
  case "${1:-}" in
    declmap)
      printf 'provision/aws.auth/resources.role-names.ts → GROVE_ROLE_NAME (role), and any declapract.use.yml → awsAccountId (account)'
      ;;
    arnconst)
      printf 'provision/aws.auth/resources.reach-arns.ts → the plain consts beside the arn builder'
      ;;
    *) return 2 ;;
  esac
}

# .what = read the grove role name out of infrastructure's own declaration
# 🛑 anchor on GROVE_ROLE_NAME — the OIDC block above it holds the SAME keys, and
#      its `prodReader` differs by one segment, so a bare grep looks right
# .why = no default key: it would compose the prep role against the prod account
# 🛑 the READER is an argument, and an unknown one REFUSES
#   - a `case` with no `*)` arm would let a future reader name fall through to
#     `declmap` and answer from the wrong file, silently
#   - ⇒ every caller passes the row's own reader; a typo halts that row
grove_provision_5_13_reach_role() {
  local reader="${1:-}" key="${2:-}" src
  [[ -n "$reader" && -n "$key" ]] || return 2

  case "$reader" in
    declmap)
      src="$(grove_provision_5_13_reach_rolesrc)"
      [[ -f "$src" ]] || return 1
      # take the GROVE_ROLE_NAME block only, then the key within it
      sed -n '/export const GROVE_ROLE_NAME/,/^} as const;/p' "$src" \
        | grep -m1 -E "^[[:space:]]*${key}:" \
        | sed -E "s/.*'([^']+)'.*/\1/"
      ;;
    arnconst)
      grove_provision_5_13_reach_tsconst \
        "$(grove_provision_5_13_reach_arnsrc)" "$key"
      ;;
    *) return 2 ;;
  esac
}

# .what = read a row's account id, by the reader the row NAMES
# 🛑 an unknown reader REFUSES, for the same reason `_role`'s does — an absent
#      `*)` arm would answer one row's key out of the other row's file
# .note = never echoed by any caller — it is dox, and this repo is public
grove_provision_5_13_reach_account() {
  local reader="${1:-}" key="${2:-}"
  [[ -n "$reader" && -n "$key" ]] || return 2

  case "$reader" in
    declmap) grove_provision_5_13_reach_account_declmap "$key" ;;
    # 🛑 the 12-digit clamp rides HERE too — an `arnconst` id composes the same
    #    `role_arn`, so a malformed one is the same defect the declmap half
    #    already refuses. one claim, two readers, one bound
    arnconst)
      grove_provision_5_13_reach_tsconst \
        "$(grove_provision_5_13_reach_arnsrc)" "$key" \
        | grep -m1 -oE '^[0-9]{12}$'
      ;;
    *) return 2 ;;
  esac
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
# 🛑 it globs the SOURCE org, never the row's target org
#   - a row may reach into an account no clone of that org declares: an ehmpathy
#     account, by a role `ahbode/infrastructure` creates, is exactly that shape
#   - ⇒ the declaration follows `_rolesrc`, which is an ahbode repo, so the two
#     readers stay pointed at one org and cannot drift apart
grove_provision_5_13_reach_account_declmap() {
  local key="$1"
  local org repo found="" found_in="" seen="" conflicts=""
  org="$(grove_provision_5_13_reach_srcorg)"

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

# .what = the ONE clone this bundle reads its declarations out of
# .why  = `_rolesrc` and `_arnsrc` name two files in one repo, so the checkout is
#         one fact and gets one holder
grove_provision_5_13_reach_srcrepo() {
  printf '%s/git/%s/infrastructure' "$HOME" "$(grove_provision_5_13_reach_srcorg)"
}

# .what = bring that clone CURRENT, where safe. stdout names which:
#         current | ahead | dirty | detached | unreachable | absent
#
# 🛑 .why THIS bundle owns the currency, and `5.10.repos` does not
#   that bundle converges PRESENCE across ~140 clones and stops, on purpose — a
#   grove is where work happens, so a blanket pull would churn trees it does not
#   own. but a bundle that READS another repo as a source of truth owes the
#   currency of that ONE clone (`rule.require.bundles-own-their-dependencies`).
#
#   📜 measured 2026-09-18 on grove-ahbode-v20260901: the demo pair HAD merged to
#   infrastructure's main, the box held the clone (138 of 138 "already present"),
#   and every apply read the stale file and declined. no command on the box could
#   close it — the deterministic clause of `rule.require.one-command-provision`,
#   defeated by a presence guard (`define.provision-defect-shapes`, shape 6).
#
# 🛑 `--ff-only`, and NEVER a merge or a rebase
#   the clone is a human's checkout. a fast-forward advances a branch that has
#   not diverged and REFUSES otherwise, so this can never author a commit, drop
#   work, or leave a conflict behind for somebody to find later.
#
# ⚠️ every non-`current` outcome is a REPORT, never a failure
#   a dirty or ahead tree is a human mid-work, which is normal on a grove. the
#   phase names what it found and reads whatever the clone holds.
grove_provision_5_13_reach_sync() {
  local repo; repo="$(grove_provision_5_13_reach_srcrepo)"

  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo absent; return 0; }

  # a tree with edits in flight is a human's, and is never advanced under them
  [[ -z "$(git -C "$repo" status --porcelain 2>/dev/null)" ]] || { echo dirty; return 0; }

  # a detached HEAD, or a branch with no upstream, offers no target to advance to
  git -C "$repo" symbolic-ref -q HEAD >/dev/null 2>&1 || { echo detached; return 0; }
  git -C "$repo" rev-parse -q --verify '@{u}' >/dev/null 2>&1 || { echo detached; return 0; }

  # 🛑 `GIT_TERMINAL_PROMPT=0` + a total bound
  #   git opens `/dev/tty` DIRECTLY to ask for a credential, and a duct IS tmux —
  #   so an unbounded ask does not fail one phase, it eats every command sent
  #   after it (`rule.forbid.tty-as-a-proxy-for-a-human`,
  #   `rule.require.bounded-probes-in-verifies`)
  GIT_TERMINAL_PROMPT=0 timeout 60 git -C "$repo" fetch --quiet origin </dev/null \
    >/dev/null 2>&1 || { echo unreachable; return 0; }

  git -C "$repo" merge --ff-only --quiet '@{u}' >/dev/null 2>&1 \
    && { echo current; return 0; }
  echo ahead
}

######################################################################
# .what = the profile name every row DECLARES, one per line
#
# 🛑 .why a bundle that only ADDS is not a bundle that CONVERGES
#   - a row wires `[profile <org>.<env>.<owner>]` and a rack entry. a row that
#     LEAVES this table takes its declaration with it and leaves both halves
#     on every box that ever applied it
#   - ⇒ the box's reach became a function of every row this repo EVER held,
#     rather than of the rows it holds now. two boxes with identical trees
#     carried different reach, by the order in which they were applied
#   - (`rule.require.one-command-provision`, its deterministic clause)
#
# 📜 measured 2026-09-18 on grove-ahbode-v20260901. an `ehmpathy:demo` row was
#   wired, wrote its profile body, died at keyrack's env enum, and was rewired
#   to `ehmpathy:test` + `ehmpathy:prep`. the row left this table and
#   `[profile ehmpathy.demo.ehmpath]` stayed on the box — live, and it named a
#   real role in a real account, under a profile no declaration owned.
#
# ⚠️ the name is composed HERE and read back by `aws.reach.get --names`, which
#   derives it from the same writer the fence does. so the diff is between two
#   answers to one question, never between two spellings of one rule
######################################################################
grove_provision_5_13_reach_declared_profiles() {
  local owner pair rest org env
  owner="$(grove_provision_5_13_reach_owner)"
  for pair in $(grove_provision_5_13_reach_envs); do
    org="${pair%%:*}"
    rest="${pair#*:}"
    env="${rest%%:*}"
    printf '%s.%s.%s\n' "$org" "$env" "$owner"
  done
}

######################################################################
# .what = the profile name every reach fence on THIS BOX carries, one per line
#
# 🛑 .why it SOURCES the grammar and does not drive `rhx aws.reach.get --names`
#   - this bundle's rule is to DRIVE the skill rather than reimplement it, and
#     that rule still holds for every WRITE: `aws.reach.set` and
#     `aws.reach.del` are driven, because each owns two halves and a live proof
#   - but a READ over `rhx` is not a read of the skill's answer. rhachet writes
#     a banner to STDOUT — measured 2026-09-18:
#
#       $ rhx aws.reach.get --names | cat -A
#       $
#       🪨 run solid skill repo=.this/role=any/skill=aws.reach.get$
#       $
#
#   - ⇒ a caller that diffs those lines against a declared set reads the banner
#     as a profile name, finds it undeclared, and tries to REAP it. the reap
#     refuses (the name holds a space and a slash), so the phase fails — on
#     every box, forever, over a line the skill never printed
#   - ⇒ so the LIST is read from the one holder of the fence grammar, in
#     process, with no transport between the answer and its reader
#   - (`project_rhx-not-pipe-safe`; `rule.forbid.failhide` — a transport that
#      edits the payload is a reader that cannot be trusted with a verdict)
#
# ⚠️ it is bounded to the fences THIS FAMILY wrote
#   - `_fence_list` reads only `# grove: reach` blocks, so `5.6.aws`'s own
#     `ambient` profile and a human's hand-written `[profile …]` are invisible
#     here and can never be reaped (`rule.forbid.two-writers-on-one-artifact`)
######################################################################
grove_provision_5_13_reach_carried() {
  local ops
  ops="$(dirname "$GROVE_SRC")/.agent/repo=.this/role=any/skills/aws.reach.operations.sh"

  # ⚠️ an ABSENT ops file yields an empty list, never a failure — a checkout
  #   pushed with `--from src` carries no `.agent/`, and a reap that cannot
  #   read the box must claim no reach rather than claim none is carried
  [[ -f "$ops" ]] || return 3

  # shellcheck source=/dev/null
  source "$ops"
  aws_reach_fence_list
}

grove_provision_5_13_reach() {
  bundle.upgrade 5.13.reach.configure.upsert
  bundle.upgrade 5.13.reach.configure.verify
}
