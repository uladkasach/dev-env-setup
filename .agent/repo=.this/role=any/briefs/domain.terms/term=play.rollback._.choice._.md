# domain.term: play.rollback

term.chosen   = rollback (as the verb slot of a play name)
term.kind     = verb
term.synonyms.forbidden:
- repair (**deleted 2026-08-10** — it named a FORWARD write, which is a bundle. the whole point of this word is that it goes the other way)
- reset (says the box returns to a start state; a rollback un-does ONE named bundle, never the box)
- clean (names tidiness, not direction — and it reads as safe, which this is not)
- teardown (destroys a subject entire; a rollback un-converges so a bundle can re-converge)
- undo (an editor's word; it implies a stack of steps and a guarantee of restoration, and there is neither)
- unapply (mechanical, and it names the inverse of a phase rather than of a bundle)

## .what

the verb of the ONE play that may write, and it writes **BACKWARD**: it puts a test box into an
unconverged state so a bundle's FIRST apply can be tested again.

it exists only in development. it is a prop that holds up a proof, never part of the answer.

## 🛑 .the axis that defines it — direction, not danger

every other question about a play that writes is a distraction. the one that decides is:

> **does this move the box FORWARD toward the declared state, or BACKWARD away from it?**

- **forward** → that is convergence, and convergence is a **bundle**. always.
- **backward, on a box I use as a test subject** → a rollback

⚠️ this is why `repair` is a forbidden synonym rather than a near-miss. `repair` named a
forward write, and all eight plays that carried it moved boxes forward — so not one of them
was a rollback, and not one survived (`rule.forbid.repair-plays`).

## .the four conditions — ALL of them, or it is not a rollback

1. **named `rollback.*`** — the word says what it does
2. **it names the bundle it un-does** — `rollback.5.1.node`, never `rollback.the-path-thing`.
   a rollback with no named bundle is a repair play with a new hat
3. **it never runs on a box that is not a test subject** — never in a howto, never in a
   procedure, never handed to a human as a fix
4. **it lives in `.play/temporary/`, which is GITIGNORED** — it has the lifespan of the
   experiment that needed it, and a play that is never committed cannot outlive one

   ⚠️ the gitignore is what enforces this — **never a human's memory to delete it later.**
   measured: memory is exactly what let the play dir grow past twice the size its own
   readme claimed (`rule.forbid.repair-plays`, condition 4)

## .the family it belongs to — three READ verbs, and this one write verb

| verb | reads? | writes? | direction |
|------|--------|---------|-----------|
| `diagnose` | yes | no | — |
| `verify` | yes | no | — |
| `prove` | yes | only via `grove.provision` or a suite | forward, to OBSERVE |
| `rollback` | — | **yes** | **backward**, and only on a test box |

⚠️ `prove` and `rollback` both write and they are not the same licence. a `prove` drives
forward *through the inventory* to observe. a `rollback` drives backward *outside*
it, because the inventory holds no entry for an un-converge — that is the whole reason it
needs its own word and its own four conditions.

## .the bar it serves, which it never substitutes for

> **`grove.provision` must run END TO END, IDEMPOTENTLY, and do EVERYTHING.**

a rollback exists ONLY so that claim can be proven twice on one box. so a rollback that
becomes a permanent fixture has **inverted its own purpose**: if you find yourself with one
on a box you did not just experiment on, the bundle does not meet the bar, and the bundle is
what to fix.

## .refs

where the term is declared:
- `.agent/repo=.this/role=any/briefs/grove/play/rule.forbid.repair-plays.md` — the rule that mints it,
  its four conditions, and the forward/backward test

⚠️ **no `rollback.*` play is tracked in git, and that is the healthy state.**
condition 4 makes the TRACKED population of this verb permanently zero — one appears in the
gitignored `.play/temporary/` for an experiment, and leaves with it. an empty `.refs` here is
evidence the word works, not evidence it is unused.

⇒ and since 2026-08-30 that emptiness is a **guarantee** rather than an observation: the dir
a rollback lives in is gitignored, so a tracked one is a defect a reader can name rather than
a lapse only its author could have noticed.

## .reason

see the ref-level cluster beside this choice:
- `term=play.rollback._.choice.reason.md` — the etymology, the human judgment that bounded it,
  and why a verb with no live instance was still worth a cluster
