# domain.term.choice.reason: play.rollback

## .etymology

*roll back* is from the ledger and the tape: to run a record BACKWARD to a prior position. the
database sense — undo an uncommitted transaction — is the one most readers already hold, and it
carries exactly the right two implications:

1. **direction is the whole content of the word.** a rollback is not defined by what it touches
   or how much damage it can do; it is defined by which way it moves.
2. **it is paired with a forward act.** nobody rolls back for its own sake. a rollback exists so
   a commit can be attempted again — which is precisely why this play exists: so a bundle's
   FIRST apply can be tested twice.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `repair` | **the word it replaces.** `repair` names a FORWARD write — it moves a box toward the declared state, which is a bundle's job and never a play's. it was deleted outright on 2026-08-10 with the eight plays that used it |
| `reset` | says the box returns to a START state. a rollback un-does ONE named bundle, and the box keeps everything else. the scope is a bundle, never the machine |
| `teardown` | destroys its subject entire. a rollback leaves the box alive and re-convergeable — that is the point |
| `undo` | an editor's word. it promises a stack and a restoration guarantee, and there is neither: a rollback is hand-written per bundle and may not restore what the bundle displaced |
| `clean` | names tidiness, not direction, and it READS AS SAFE. the most dangerous property of this verb is that it writes, so a soothing word is the wrong one |
| `unapply` | mechanically apt and it names the inverse of a PHASE. the unit here is a bundle |

## .what settled it — a human bounded the exception in three sentences

the round that deleted `repair` left an obvious hole: if a play may never write, how do you
test a bundle's first apply twice on one box? the human answered it in three messages, and
each one narrowed the exception further:

> "adhoc plays are only allowed in exceptional circumstances when the bundles themselves were
> defective. basically, as a rollback"

> "during experiementation"

> "and development"

then, immediately, the clause that stops the exception from eating the rule:

> "yeah, but the bundle should be able to idempotently run end to end and do everything"

⇒ **the exception and the bar arrived together, in that order.** that sequence is the term's
whole content: the licence to write backward is granted *in service of* the requirement to
converge forward, and it is void the moment it is used for any other purpose.

## .why a term for a verb with ZERO live instances

this is the unusual part, and it is deliberate.

`rule.require.domain-term-itemization` anchors a term on a **declared** dobj/dop, and
`gotcha.my-own-note-became-my-evidence` warns hard against a term minted for an operation the
repo does not declare. so the obvious objection is: no `rollback.*` play exists — is this the
`git.grove.rebuild` mistake again?

it is not, and the difference is where the declaration lives:

| | `git.grove.rebuild` (the mistake) | `play.rollback` (this term) |
|---|---|---|
| who first named it | a relayed sentence from outside the repo | a rule file **in** this repo |
| can I reach the declaration without a hop through my own text? | no — every reference was mine | yes — `rule.forbid.repair-plays` declares it, and a human dictated its bounds |
| what a glob proves | the skill family does not hold it ⇒ the term had no ground | the rule holds it ⇒ the term is grounded in a declaration, not in an instance |

⇒ **the anchor is the RULE, not a play file.** the verb is declared, its four conditions are
declared, and its enforcement clause is declared. what is absent is an *instance* — and
condition 4 (*deleted when the bundle it served is proven*) makes zero instances the
**expected steady state**, not an accident.

that inverts the usual `.refs` test in a way worth stated plainly:

> for this one term, a populated `.refs` is the warning sign. an empty one is health.

## .the risk the term exists to hold down

a verb that licenses a write is the most dangerous kind of entry in this glossary, because the
rule beside it says a play may NEVER write. so the failure mode is not that `rollback` goes
unused — it is that `rollback` becomes the hat every forward write puts on.

that is not hypothetical. it is what happened to `repair`: eight plays, over months, each one
individually justified, teaching by their mere presence that a play which writes is a normal
part of this repo. the four conditions exist to make the same drift *detectable per file*
rather than only visible in aggregate:

- condition 2 (**name the bundle**) is the one that bites first. a forward write has no bundle
  it un-does, so its author cannot satisfy this condition without a lie that is obvious in the
  filename.
- condition 4 (**delete when proven**) is the one that stops accumulation, which is the
  mechanism by which `repair` became normal.

## .evidence

- **the eight deleted plays.** every one moved a box FORWARD. not one was a rollback. so the
  new verb, applied retroactively, would have rejected the entire population it replaces —
  which is the strongest available evidence that the direction axis is the right cut
  (`rule.forbid.repair-plays`, the 📜 table).
- **the two plays deleted with no bundle to inherit them** — `repair.grove-root-strays` and
  `repair.keyrack-drop-probe-keys` — are the closest historical near-misses, because both
  cleaned up a MISTAKE rather than converged a state, so both *feel* backward. they still fail
  condition 2: neither names a bundle it un-does, because neither un-did a bundle. the durable
  fixes were a guard in `git.grove.push` and a diagnose that stores no key.
- **the narrative test** (`def.domain-discovery`): a traveler says *"roll the box back to
  before 5.1.node, so I can test the first apply again."* the sentence is speakable, names its
  bundle unprompted, and its direction is unmistakable. `repair` cannot be spoken that way —
  *"repair the box to before 5.1.node"* is incoherent, which is the tell that it was always a
  forward word.

## .disputes

no dispute is open.

📌 one is FORESEEABLE and worth pre-recorded, because the argument is tempting: someone will
propose a relaxed condition 3 (*never on a box that is not a test subject*) to allow a rollback
on a production grove that a bad bundle damaged. the counter, stated once now: a damaged grove
is **disposable** (`rule.require.prove-changes-on-a-grove`), so the answer is a fresh box and a
fixed bundle. a rollback run in production is a repair play by any other name, and the four
conditions would have to be abandoned to permit it.

## .see also

- `rule.forbid.repair-plays` — the rule that declares this verb and bounds it
- `term=play.prove._.choice._.md` — the other verb that may write, and why its licence differs
- `term=play.verify._.choice._.md` — where the read-only guarantee is argued from etymology
- `term=bundle._.choice._.md` — what a rollback un-does, and the unit it names
- `gotcha.my-own-note-became-my-evidence` — the trap this term's `.why zero instances` answers
