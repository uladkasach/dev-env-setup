# demo: 5.13.reach — every measurement behind the per-org rows and the reap

## .what

`5.13.reach` gives a box an aws identity in each env its suites target. each row below is a
measurement that shaped one clause of its header — the per-org split, the two readers, the
currency it owns, and the fence it reaps.

## m1 — one scalar spelled TWO orgs, and they parted on 2026-09-13

a row carries two independent org axes:

| axis | what it names | where it lives |
|---|---|---|
| the SOURCE org | whose clones DECLARE the role + account id | `_srcorg` |
| the TARGET org | whose account the profile REACHES into | the row |

- 📜 they agreed for every row until 2026-09-13, so one scalar spelled both
- then a grove needed reach into an EHMPATHY account, by a role that
  `ahbode/infrastructure` declares — infra is what CREATES a cross-account role, whatever
  account it points at
- a scalar cannot hold that: the account must be read from ahbode's clones while the
  profile is NAMED `ehmpathy.<env>.<owner>`
- ⇒ the prior comment's own estimate held: it said a second org costs *"a table plus a loop
  in BOTH halves"*, and cited `5.12.rack`'s precedent. that is exactly what it cost

## m2 — a flat `_srcorg` had an AETHER grove read AHBODE's declarations

- 📜 2026-09-24: the scalar was `ahbode`, so an aether grove read ahbode's declarations,
  composed ahbode's role arns, and was **correctly refused by aws five times**
- a source org is a fact about whose infra declares a row, so it belongs to the grove's own
  org and not to this file's history
- 🛑 an org with no source repo has no rows to read, so `_srcorg` returns empty and `_envs`
  returns empty beside it. **both halves refuse together**, which is what keeps a
  half-applied pair impossible
  (`rule.require.a-grove-reaches-its-own-org-only`, clause 3)

## m3 — the row table was a flat scalar, so every grove was told to want five hops

- 📜 2026-09-24: five ahbode/ehmpathy rows sat in a flat scalar, so EVERY grove wanted
  them, whatever org it belonged to
- an aether grove asked aws for five hops it may not make, collected five `AccessDenied`s,
  and **an infra ask was drafted to have them GRANTED** — a permanent cross-account
  expansion, to silence a check that was right
- ⇒ the rows now sit under the org they belong to, and an org with no arm gets none
- 🛑 the two ehmpathy rows are AHBODE's opt-in and stay under ahbode. ehmpathy demo is
  generic infra, which is why ahbode could opt into it at all — that says not one word
  about aether, or any other org

## m4 — `demo` names an ACCOUNT, never a tier, and keyrack's enum was the signal

- ehmpathy holds ONE non-prod account and both of its non-prod tiers land in it
- measured in `ehmpathy/sdk-aws-lambda`: `.github/workflows/test.yml` and `publish.yml`
  both oidc into that one account, and its `.agent/keyrack.yml` declares
  `env.prep: [AWS_PROFILE]` — so the slug a suite READS is `ehmpathy.prep.AWS_PROFILE`,
  never `ehmpathy.demo.*`
- 📜 a `demo` row was wired first and died at its own callee: keyrack's
  `KEYRACK_VALID_ENVS` holds no such value, so the profile body landed and the rack name
  refused — a half-applied pair
- ⇒ **the enum was the SIGNAL, never the defect.** `demo` was the wrong axis; two rows, one
  account key, and a row per TIER is what a consumer selects by

## m5 — the two ehmpathy rows cannot use `declmap`, by infra's own design

- `GROVE_ROLE_NAME`'s keys are TIER-shaped — `prepPower`, `prodReader` — so an org-shaped
  `ehmpathyDemo` key would cross the axes inside the map itself
- infra's own fulcrum rules that a name it does NOT OWN may not sit in a slot whose
  contract claims source-of-truth, so the demo pair sits beside the arn builder instead, as
  `ACCOUNT_ID_EHMPATHY_DEMO` + `DEMO_POWER_ROLE_NAME`
- 📜 measured 2026-09-14 against `ahbode/infrastructure`'s reach branch: a grep for
  `ehmpathyDemo` across that tree returns **ONE hit, and it is the fulcrum line that
  forbids the key**
- ⇒ this row read that key for a day, so its decline said *"not readable HERE"* for a name
  that will never be readable ANYWHERE
  (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
- ⇒ hence the `<reader>` field: a row NAMES its reader, and no reader falls back to the
  other. a fallback would read a typo'd key as "the other source's job" and decline with a
  reason that names the wrong repo (`rule.forbid.failhide`)

## m6 — a presence guard left a stale clone unreadable by any command on the box

- 📜 measured 2026-09-18 on grove-ahbode-v20260901: the demo pair HAD merged to
  infrastructure's main, the box held the clone (`5.10.repos` reported 138 of 138 "already
  present"), and **every apply read the stale file and declined**
- no command on the box could close it — the deterministic clause of
  `rule.require.one-command-provision`, defeated by a presence guard
  (`define.provision-defect-shapes`, shape 6)
- ⇒ `5.10.repos` converges PRESENCE across ~140 clones and stops, on purpose: a grove is
  where work happens, so a blanket pull would churn trees it does not own. but a bundle that
  READS another repo as a source of truth owes the currency of that ONE clone
  (`rule.require.bundles-own-their-dependencies`)
- 🛑 `--ff-only`, never a merge or a rebase: the clone is a human's checkout, and a
  fast-forward advances an undiverged branch and REFUSES otherwise — so this can never
  author a commit, drop work, or leave a conflict for somebody to find later

## m7 — a bundle that only ADDS is not a bundle that CONVERGES

- a row wires `[profile <org>.<env>.<owner>]` AND a rack entry. a row that LEAVES the table
  takes its declaration with it and leaves both halves on every box that ever applied it
- ⇒ the box's reach became a function of every row this repo EVER held, rather than of the
  rows it holds now. **two boxes with identical trees carried different reach, by the order
  in which they were applied**
- 📜 measured 2026-09-18 on grove-ahbode-v20260901: the `ehmpathy:demo` row of m4 wrote its
  profile body, died at keyrack's enum, and was rewired to `ehmpathy:test` +
  `ehmpathy:prep`. the row left the table and `[profile ehmpathy.demo.ehmpath]` **stayed on
  the box** — live, and it named a real role in a real account, under a profile no
  declaration owned
- ⇒ `rule.require.one-command-provision`, its deterministic clause

## m8 — `rhx` writes a banner to STDOUT, so a READ over it reads the banner as data

the bundle's rule is to DRIVE the skill rather than reimplement it, and that holds for every
WRITE — `aws.reach.set` and `aws.reach.del` are driven, since each owns two halves and a
live proof. a READ is where it breaks:

- 📜 measured 2026-09-18:

  ```
  $ rhx aws.reach.get --names | cat -A
  $
  🪨 run solid skill repo=.this/role=any/skill=aws.reach.get$
  $
  ```

- ⇒ a caller that diffs those lines against a declared set reads the banner as a profile
  name, finds it undeclared, and tries to REAP it. the reap refuses (the name holds a space
  and a slash), so the phase fails — **on every box, forever, over a line the skill never
  printed**
- ⇒ so the carried list is read from the one holder of the fence grammar, IN PROCESS, with
  no transport between the answer and its reader
  (`rule.forbid.failhide` — a transport that edits the payload is a reader no verdict may
  rest on)
- ⚠️ and the reap is bounded to the fences THIS FAMILY wrote: `_fence_list` reads only
  `# grove: reach` blocks, so `5.6.aws`'s own `ambient` profile and a human's hand-written
  `[profile …]` are invisible to it and can never be reaped
  (`rule.forbid.two-writers-on-one-artifact`)

## m9 — a first-match account read is a redirect nobody can see

the `declmap` reader globs every clone under `~/git/<org>/` that declares `awsAccountId`:

- the glob spans EVERY clone there, all writable
- a first-match winner is whatever `sort` puts first, so `aaa-repo` outranks infra
- the value becomes a `role_arn` this box then assumes into
- ⇒ **one altered file redirects which ACCOUNT is reached, and says so nowhere**
- so a disagreement HALTS and names the files, rather than pick a winner — the same shape as
  the grove trust anchor's (`git.grove.trust.gen`)

⚠️ two bounds ride beside it, and each closes a path back into m2's defect:

| the bound | what it stops |
|---|---|
| exactly 12 digits, never `{6,}` | an aws account id IS twelve digits; a malformed one composes a `role_arn` that reads as an infra defect |
| an EMPTY source org must never reach the glob | `"$HOME/git/"/*/…` collapses to `~/git/*/…`, which spans every org's clones — m2's defect, re-entered through a path-join |

⚠️ and the block is read with `awk`, never a `sed` range: the boundary is INDENTATION, which
a range cannot express; three keys carry `dev`/`prep`/`prod`, so a bare grep reads a
hostname; a range closes on its own first child, so every other key reads empty. and it
fails SOFTLY — the verify reads an unreadable account as `🌙`.

## m10 — the verify's refusal: THREE causes read identically, and want OPPOSITE fixes

| the refusal says | the cause | who repairs it |
|---|---|---|
| AccessDenied on sts:AssumeRole | 🔴 this grove's ORG has no business in that account | a ROW in THIS repo — delete it |
| AccessDenied on sts:AssumeRole | the role EXISTS and this box sits outside its TRUST POLICY | a DECLARATION in another repo |
| every other refusal | a half-applied pair — the profile is named and aws cannot find its body | a re-apply of THIS bundle |

- 🛑 rows 1 and 2 are INDISTINGUISHABLE to aws, and only the ORG sorts them — so the two questions
  go IN ORDER (SHOULD this box reach here at all? only then: is it TRUSTED to?), and the code
  CANNOT ASK THE FIRST: a row that should not exist reads exactly like one that should
- 📜 2026-09-23, `grove-aether-v20260921`: FIVE rows took the first cause, and the branch printed
  the second one's diagnosis plus `fix: … --what 5.13.reach --mode apply`. that re-apply was RUN
  and refused identically — the box was unrepairable by the only command it was given
- 📜 2026-09-24: the same five drafted an infra ask to have them GRANTED — m3. it would have bought
  an aether box a permanent assume-role into ahbode prod, to silence a check that was right
- ⚠️ the bundle STATED the own-org rule at the top of that very loop, and honored it in the two
  declines above it — recited on the page it was broken on, which is why the sort now lives in
  code rather than a comment
- NO id is printed for either cause: the SHAPE of the refusal rides out, the identifiers do not
- the refusal is CAPTURED, never `2>/dev/null`: aws's own sentence is the ONE fact that sorts the
  causes, and discarded it let the branch name only the rarer one

### the verify's other choices

- it re-asks what the upsert proved: `--mode plan` short-circuits every upsert and runs every
  verify, so a plan is the one read that says a box is converged — and a drift only the upsert
  saw is a drift no plan reports
- it checks the ACCOUNT, never merely that a call succeeds: a profile aimed at the wrong account
  assumes CLEANLY, and only the returned identity tells the two apart
- an UNWIRED row whose declaration is unreadable is UNPROVEN, never broken: the upsert declined
  on the same two reads, so a ✋ would ask for a re-apply that declines identically, forever
- an undeclared carried fence is a ✋, not a 🌙: a live profile under a name the repo no longer
  owns is reach nobody decided to grant, and one apply reaps it

## m11 — the upsert's measurements, one per block

- **it DRIVES `aws.reach.set`, never reimplements it**: the skill writes BOTH halves and proves
  the pair with a live sts call — an inlined body forks one logic into two places. the bundle
  adds only the two inputs the skill cannot derive. CONFIGURE, since both halves sit in `$HOME`
- **the ambient gate**: every profile sets `credential_source = Ec2InstanceMetadata`, so the box's
  badge does the assume and a laptop has none. `5.12.rack` and `5.6.aws` decline on the same fact
- **the clone is NAMED from `_srcorg`** — 📜 2026-09-24, grove-aether-v20260921: every arm spelled
  `ahbode/infrastructure` as a literal, so an AETHER box printed `🌙 ahbode/infrastructure is not
  cloned` with a fix to clone another org's private infra repo onto it. the verdict was right and
  the SUBJECT wrong (m.4). an org with NO source is a different fact from an absent clone, and
  `_sync` answers `absent` for both, so the split is made where `_srcorg` is readable
- **the no-source branch REPORTS and falls through**: a `return` would skip the reap, and an org
  set with no rows genuinely wires no reach — its fences ARE undeclared. `_envs` returns empty,
  so the loop needs no guard (`rule.require.fewer-paths-via-idempotency`)
- **every `rhx` runs from the CHECKOUT ROOT** — 📜 2026-08-12, one box, one minute apart: from
  `$HOME`, `✋ no skill "aws.reach.set" found in any linked role`; from the checkout, the skill
  answered. rhachet links a `repo=.this` role relative to the git root it runs from
- **`$checkout` is hoisted ABOVE the loop**: a `local` inside a loop is function-scoped and read
  fine — until a box where EVERY row declined before that line, the reap ran with it unset, and
  `set -u` killed the phase on the box class that most needed the reap
- **each row DECLARES its org first** — 📜 with `ehmpathy` left declared by `5.12.rack`'s loop,
  all three rows died on `org "ahbode" does not match keyrack.yml org "ehmpathy"`, AFTER each had
  written its `~/.aws/config` body — a half-applied pair. `5.12.rack` OWNS the scratch yml; each
  borrower re-states its org, PER ROW, since the rows no longer share one
- **a decline names the row's OWN reader's file** (`_declsrc`, m.9) — a fixed `GROVE_ROLE_NAME`
  sentence sent a human to a file whose contract FORBIDS that key
- **the decline names the clone's measured STATE** — an absent clone and a present-but-behind one
  read identically to the reader, with opposite repairs. 📜 2026-09-18: the old menu's "behind"
  arm said the declaration had not merged and no command could close it — it HAD merged, the
  clone was stale, and a fetch closed it (m.4). the role is never GUESSED: a wrong name refuses
  with the same AccessDenied as a role that excludes this box
- **`--assume`, NEVER `--role`** — 📜 2026-09-01, a from-scratch grove: `--role "$role"` gave
  `✋ --assume is required for --env test`. RHACHET injects `--role <slug>` itself, so the skill
  cannot tell it from a caller's iam role and drops it — correct at the callee, so each caller
  owes the sweep. only a FROM-SCRATCH box could show it: a converged one already answers
- **the failure's CAUSE is read from the log** — 📜 2026-08-12: an unconditional AccessDenied claim
  printed above `no skill "aws.reach.set" found in any linked role`; no AssumeRole had run. the
  log reads use no `-q`, since a matched `grep -q` under pipefail takes the ELSE branch
- **the REAP** — a bundle that only ADDS never converges: a row that left the table left both
  halves on every box that applied it, so two identical trees carried different reach by apply
  order (m7). it reaps by DECLARATION, never a hand list of dead names, which rots silently. it
  is bounded to `# grove: reach` fences, so `ambient` and a human's own profiles are invisible
- **an UNKNOWN org NEVER drives a reap**: "org set, no rows" and "org EMPTY" both leave `declared`
  empty, and only the first is safe — with no org, no table was read, every fence looks
  undeclared, and the reap strips the box. a `--from src` push makes that a REAL state
- **a WHOLE-LINE match in pure bash**: `ehmpathy.test.ehmpath` is a prefix of `…ehmpath2`, so a
  partial match would spare a live fence, and a `grep -q` in a pipe SIGPIPEs its producer. the
  org+env are cut from the RIGHT of `<org>.<env>.<owner>`, since an org may hold a dot

## .see also

- `5.13.reach/_.sh` — the header these measurements back
- `5.13.reach/configure.verify.sh` — m10's phase
- `5.13.reach/configure.upsert.sh` — m11's phase
- `howdoes.a-box-reach-an-aws-account.md` — every `.why` of that header, in full
- `rule.require.a-grove-reaches-its-own-org-only` — the rule m2 and m3 bought
- `rule.require.one-command-provision` — the deterministic clause m6 and m7 break
- `gotcha.5-12-rack.demo=entry-vs-value` — the neighbor bundle, and the same flat-scalar
  defect one level up
