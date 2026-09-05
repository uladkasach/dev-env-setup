# domain.term.choice.reason: play.verify

## .etymology

*verify* is from latin *verus* — true. to verify is to judge whether a claim is TRUE, which
presupposes the claim already holds or fails before you look. that is the whole content of the
read-only guarantee, carried inside the word: an act that changes the machine has replaced the
state whose truth it was asked about.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `check` | says a claim was LOOKED AT, not that it was judged. `check.tree` could report and exit 0 with every claim failed |
| `test` | jest owns this word in the repo (`git.repo.test`, `*.test.ts`). a play is not a test suite and does not run in ci |
| `ensure` | names an act that MAKES a claim true — and an act that makes a MACHINE claim true is a **bundle**, never a play (`rule.forbid.repair-plays`). to blur the two is how a read-only play acquires a write |
| `validate` / `confirm` | synonyms with no added sense; `rule.forbid.domain-term-synonyms` |
| `audit` | reserved, and correctly: `audit.creds` reports an INVENTORY and asserts no verdict. an audit answers "what is here", a verify answers "is the claim true" |

## .what settled it — a `verify.*` play that ran `--mode apply`

`verify.grove.provision.applied.play.sh` had a section 4 that executed a real
`install_env._.sh --for cloud --mode apply` to prove idempotency. the human read it
and said, with no hint from me:

> and what is verify.grove.provision.applied ? seems weird

the weirdness they felt was this exact overload. three consequences, all real:

1. **the prefix lied.** a traveler who needs to inspect a machine they must not disturb reads
   `verify` and runs it. it wrote files.
2. **the play could not serve its own purpose.** a verification you cannot run on a delicate
   box is not much of a verification.
3. **it hid a second defect.** the same play opened with seven `diff ~/.bash_aliases
   $SRC/bash_aliases.sh` ticks against a step whose body is `cp "$SRC/bash_aliases.sh"
   ~/.bash_aliases`. those ticks cannot go red unless `cp` is broken — and seven green
   tautologies read as coverage, so nobody looked further. the claim actually worth a check —
   *is the src a live checkout that can be refreshed* — was omitted, and the machine had been
   sat on a frozen git-less copy the whole time.

so the overload was not cosmetic. **the word that could mean two acts produced a play that did
neither well.**

## .the family contrast, and why the split is the VERDICT

the intuitive split is "does it write?" — but that misses the `diagnose` / `verify` boundary,
where neither writes:

- `diagnose.grove-github-credential` reads every link between the rack and its two consumers
  **and asserts none**. that is the whole point: `absent 🫧` is one word for four states, and
  a verdict would collapse them into one answer and hide which link decided. the same shape
  exposed the `--for` ec2 defect (`term=--for._.choice.reason.md`)
- `verify.tree.parity` asserts — every tool present, or it names each absent one

> a diagnose that asserts a verdict hides the branch a reader needed.
> a verify that asserts none is a log.

## .why `play.verify` and not a bare `verify`

`.readme.md`'s scope test: *could another domain object in this repo take this same word?* yes —
plainly. so the term carries its bounded context as a prefix. the literal string sits at the
FRONT of a play filename (`verify.tree.parity.play.sh`) while the term reads `play.verify`;
the term names the slot's context, not the character order.

## .the deferral, with a condition that can actually end it

`play.diagnose` is named in the table above but holds no cluster of its own. this is deliberate
and, unlike the six-round `duct` deferral, it names its trigger:

> **the trigger:** it earns its own cluster the moment a defect turns on ITS boundary — a
> diagnose caught with a verdict — or the moment someone disputes its word.

`verify` earned its cluster exactly that way, today. `diagnose` has not yet, and a term minted
before a real judgment is the `slice` mistake of round 20.

📜 `play.repair` WAS deferred here alongside it, then itemized, then **deleted on 2026-08-10**.
its boundary turned out not to exist: a play may not write machine state at all, because that
is a bundle (`rule.forbid.repair-plays`). the deferral was resolved by deletion of the concept,
not by a cluster.

## .evidence

- seven `verify.*` plays predate this itemization and every one is read-only — the convention
  was already real, only unwritten. the one exception is the defect above
- the playbook readme said *"name it for what it does"* but never declared the verb
  family, which is how the exception passed review
- the narrative test: a traveler says "verify the parity" and "diagnose the detection" — the
  split is spoken aloud, which is the bar `def.domain-discovery` sets

### ⚠️ the defect RECURRED — 2026-08-08, and the recurrence is the stronger evidence

`verify.svc-chat-integration.play.sh` was extended into a regression watchdog and kept its
`verify.` prefix while it wrote three times before it judged one claim:

| the write | what it mutates |
|---|---|
| `pnpm install --frozen-lockfile` | node_modules |
| `rhx keyrack unlock` | the daemon's in-memory session |
| the integration suite itself | rows in the testdb |

it was renamed to `prove.svc-chat-integration.play.sh`.

⇒ **this is the same overload that minted the term, in a file whose name was never re-asked.**
the first instance was caught by a human's *"seems weird"*; the second by the hourly redistill,
which is the mechanism that exists precisely because the first needed a human.

three things this settles:

1. **the count is now eight-plus-two, not seven-plus-one.** the "convention was already real,
   only unwritten" line above is too kind to us: a WRITTEN convention was also broken, so the
   defect does not come from an unwritten rule. it comes from a name inherited without a re-read.
2. **an EXTENDED file is a new naming decision.** the prefix was correct when the play only ran
   a suite report; it went wrong when the play grew `pnpm install` and `keyrack unlock`. nobody
   renamed a file — the file's BEHAVIOR walked across the boundary while its NAME stood still.
   ⇒ **re-ask the verb whenever a play gains a step**, not only when a play is born.
3. **the deferral trigger above is unchanged.** this defect turned on `verify`'s boundary, which
   already holds a cluster; `play.diagnose` still holds none, correctly.

## .disputes

### dispute: a cost axis beside the write axis — raised 2026-08-08 — status: RESOLVED (keep one axis)
- raised.by  = mechanic, mid-rename
- claim      = the family's single axis (does it write?) cannot separate two plays that BOTH
               write and both judge — `prove.svc-chat-integration-e2e` rebuilds the box in
               minutes, `prove.svc-chat-integration` runs a suite in seconds. a second axis
               (cost, or depth-of-drive) would name that, and a watchdog needs the cheap one
- counter    = the family's axis answers *what does this play do to the machine*, and both
               plays answer it identically: they drive, then judge. cost is a property of the
               SUBJECT each drives (bundles vs a suite), not of the verb. a cost axis in the
               verb slot would put `prove.quick.*` / `prove.deep.*` into every name and state
               what the `-e2e` suffix already states. worse: the axis was reached for to
               license a `verify.` prefix on a play that writes — a taxonomy proposed to excuse
               a name is exactly the drift `rule.forbid.domain-term-synonyms` forbids, dressed
               as a rubric
- resolution = keep the single write axis. the two plays differ in SCOPE, stated in the subject
               slot (`-e2e`) and in each play's header, never in the verb. closed the same
               round it opened
