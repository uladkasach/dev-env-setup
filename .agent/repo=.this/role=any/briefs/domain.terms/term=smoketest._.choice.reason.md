# domain.term.choice.reason: smoketest

## .etymology

from hardware, and the literal sense is the useful one: you assemble a board, apply power, and
watch for smoke. it says none of whether the thing is CORRECT — it says only that the thing
does not fail at the first real demand.

that is exactly the claim this repo needed and did not have. every extant signal was a claim
ABOUT a box (a plan, a verify, a rung). none was the box **doing a job**. the word already
means "the cheapest run that shows the thing works at all", so it was adopted rather than
invented.

⚠️ the word carries one connotation this usage deliberately keeps and one it deliberately
drops:

| the hardware sense | kept here? |
|---|---|
| it exercises the real thing under real power | **kept** — it runs the real suite, not a stub |
| it is the FIRST gate, before deeper testing | **kept** — no work is sent to a grove before it |
| it is shallow / quick | **dropped** — this one takes minutes and runs a full suite |

the third is why `healthcheck` is forbidden: a healthcheck is cheap and recurring, and a
reader who inherits that connotation would build a timer around this and wonder why the box
is busy.

## .why a SKILL and not a play

this repo's read-only family already had three verbs (`diagnose`, `verify`, `prove`), so the
first instinct was a fourth play. it is not one, for two reasons:

1. **plays are read-only, and this writes.** `rule.forbid.repair-plays` is absolute about a
   play that touches the machine, and it names only two exceptions (a `rollback`, a
   discrimination probe). a smoketest is neither: it writes FIXTURES, forward, on every run.
2. **plays are carried down a duct; this is a human's command.** every play is sent with
   `git.grove.send --play`. a smoketest is the thing a human types when they want to know
   whether a box is ready, so it is a skill with a `--help`, like every other `grove.*` verb.

⇒ the family it joins is `grove.wake`, `grove.push`, `git.grove.ready.verify` — the operations a
human performs ON a grove — not `verify.*` / `prove.*`, the plays a grove performs on itself.

## .disputes

### dispute: prove  —  raised 2026-08-12  —  status: RESOLVED (keep `smoketest`)

- raised.by  = the author, while `grove.smoketest.sh` was written
- claim      = `prove` is this repo's settled word for *"establish a property by MAKING the
               machine demonstrate it"*, and that is precisely what this does. it drives real
               runs, then judges what they produced. a fifth word for the same act is the
               synonym sprawl `rule.forbid.domain-term-synonyms` exists to stop.
- counter    = three splits, and each one alone would settle it:
               1. **the subject differs.** a `prove`'s subject is a CLAIM about a run — *is
                  this idempotent? does the tree settle? does the chain break?* a smoketest's
                  subject is a BOX's CAPABILITY. one is a property of a procedure; the other
                  is a property of a machine.
               2. **the licence differs.** `term=play.prove` states its write licence
                  narrowly: *"every write it makes is a call INTO the inventory"* —
                  `grove.provision`, or a suite. a smoketest writes a testdb and a
                  `node_modules`, neither of which the inventory declares. to call it `prove`
                  would either break that sentence or force it to be loosened, and it is
                  load-bear.
               3. **the location differs.** a `prove` is a play, and plays ride a duct. this
                  is a skill a human types.
- resolution = keep `smoketest`; record `prove` as a forbidden synonym here, and record
               `smoketest` as forbidden in `term=play.prove` should a play ever reach for it.
               the two words now split cleanly on subject: **a `prove` proves a BUNDLE; a
               smoketest proves a BOX.**

### dispute: acceptance  —  raised 2026-08-12  —  status: RESOLVED (keep `smoketest`)

- raised.by  = the author, from the human's own framing — *"that should be the acceptance
               criteria for any new grove"*
- claim      = the human named it acceptance criteria, so `grove.acceptance` names the thing
               by the role it actually plays.
- counter    = "acceptance" names a **status conferred**, not an **act performed**. a command
               is a verb slot, and the verb here is *run a job and judge it*. the acceptance
               is what the exit code EARNS, which is why that framing lives in the rule
               (`rule.require.smoketest-before-a-grove-is-declared-ready`) rather than in the
               command name.
- resolution = keep `smoketest` for the command; the word "acceptance" carries the rule.

## .evidence

- **the gap it closes, measured 2026-08-12** — a box reported `✔ 127 · ✋ 0` on ground and
  `✔ 125 · ✋ 0` on camper while `git.repo.test` on svc-chat ran **0 tests**. three faults
  stood in between (absent `node_modules`, unprovisioned testdb, absent `ACCESS` envar) and no
  bundle verify could see any of them, because none is grove state.
- **determinism, measured rather than asserted** — two consecutive runs on
  `grove-ahbode-v20260811`, with no hand step between them, produced byte-identical step
  verdicts and the same tally (`31 passed, 0 failed`).
- **the latest-main choice** — the suite runs against latest `origin/main`, never a pinned
  sha. svc-chat's main is green by invariant (cicd gates it), so latest main is a fixed point
  that needs no keeper, where a pin goes stale and grows one. the cost is named where it
  lands: step 4's halt says *"UNLESS main shipped red, which this gate trusts it never does"*,
  and prints the `gh run list` that settles it.

## ⚠️ .the open debt on this term

the gate has been seen to go **green** on a healthy box, twice. it has **never been seen to go
red**, so by this repo's own standard it is half proven
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary for anyone who writes a
check`). a discrimination probe under `rule.forbid.repair-plays`' exception 2 is what would
close it.

⇒ until that probe exists, a green smoketest is evidence the box works and **not** evidence
that the gate would have caught a box that does not.
