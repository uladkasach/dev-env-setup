# domain.term.choice.reason: plant

## .etymology

**the word was not coined here. it was already in the repo's prose, at say level.**

`gotcha.a-check-that-cries-wolf-gets-silenced` m.12 states the device and names it in the same
breath:

> *what answers it is a **planted row in the LIVE subject**: write one dead pointer, one
> fabricated package, one impossible sha into the real corpus … and watch.*

so the term is **incumbent**. to reach for a fresh word would be drift off a declared one,
which `rule.forbid.domain-term-synonyms` forbids outright.

`plant` also carries the right two senses at once — to place a row on purpose, and to place it
so it will be found. both are exactly what the device does.

## ⚠️ .the overload this cluster RESOLVES

`plant` was used, before this cluster, for **two different subjects**:

| usage | site | what it named |
|---|---|---|
| a fixture member | `term=fixture._.choice._.md` `.refs`, and several plays' prose | a synthetic file the play wrote |
| a live-corpus break | `gotcha…cries-wolf` m.11, m.12 | a deliberate defect in the REAL subject |

that is an ambiguous overload, and it hides the one distinction the device exists for: **a
synthetic member inherits its author's blind spot, and a live one does not.**

⇒ resolved by the extant word for the first sense. `term=fixture` already declares it:

> *one member of a fixture is an **arm**: one file, one wanted verdict, one reason.*

so **an arm is synthetic; a plant is live.** a play's prose that says "planted shapes" about
its own fixture means `arm`, and conforms on contact
(`rule.prefer.wickup-touched-prose` — fix forward, in scope, never a sweep).

## .disputes

### dispute: graft — raised 2026-08-30 — status: RESOLVED (keep `plant`)
- raised.by  = the mechanic, mid-distillation
- claim      = `graft` is more precise and unoverloaded. it names a live insertion into a live
               host that either TAKES or does not, and that is removable — which maps onto the
               device exactly, and covers m.5's *"the fixture did not take"* hazard as well.
               it also fits this repo's arboreal family (grove, tree, forest, floor, rung).
- counter    = the word is not ours to choose. m.12 already says *planted row*, at **say**
               level, in the brief this device's whole justification comes from. a term
               swapped for one that merely reads better, against an incumbent loaded into
               every session, is precisely the drift `rule.forbid.domain-term-synonyms` names
               — and it would strand every citation of m.12's sentence.
               ⚠️ and the overload `graft` was reached for to escape is resolved more cheaply
               by the extant `arm`, which was already declared and already means the other
               sense.
- resolution = keep `plant`; record `graft` here as considered and declined. the overload is
               settled by `arm` / `plant`, not by a third word.

## .evidence

### the measurement that settled it — 2026-08-30, the `bhrain` prose reviewer

| run | subject | planted? | verdict | output tokens |
|---|---|---|---|---|
| 1 | the empty set (0 files) | — | `0 / 0` | — |
| 2 | `rule.require.briefs-obey-the-prose-rules.md` — 1.2k tok | no | `0 / 0` | 898 |
| 3 | `rule.require.one-command-provision.md` — 21k tok | no | `0 / 0` | 337 |
| 4 | the run-2 file, one ramble planted | ✔ | **1 blocker 🔴** | 1,800 |
| 5 | the run-3 file, one ramble planted | ✔ | **1 blocker 🔴** | 4,578 |

runs 1-3 supported a `🛑`-level claim that the reader was blind. runs 4 and 5 refuted it. both
plants were removed in the same session; both files were byte-restored (87 and 1502 lines) and
a grep for the plant marker returned 0.

### why the two supports of the wrong claim are worth a record

| support | why it does not hold |
|---|---|
| three `0/0` runs | that is the definition of a check **not yet planted against**. "never seen to bite" is a fact about the runs chosen, not about the reader |
| output tokens FELL 898 → 337 as the subject grew 17× | output tokens track what a reader FOUND. run 5 read the same 21k file and spent 4,578 |

⇒ the second is the sharper half, and it generalizes past this device: **a plausible,
specific, quantitative metric can point the wrong way**, and it carries more authority than a
vague one precisely because it has a number attached (m.7, from its author's side).

## .invariants

forbidden combinations, each checkable:

- a **plant left in the tree** past the session that made it = **blocker**. it is a real
  defect from that moment on, and its marker makes it read as deliberate
- a plant whose **removal is claimed rather than verified** = **blocker**
  (`rule.require.trust-but-verify`) — re-read the byte count AND grep the marker
- a plant placed in a **fixture** = it is an `arm`; the word `plant` may not be used for it
- a plant **broad enough to redden more than one check** = **nitpick**; it implicates none
- a `0`-verdict run cited as evidence that a reader is **blind**, with no plant run =
  **blocker**. that is a null result spent as a negative one
