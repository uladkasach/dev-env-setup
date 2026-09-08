# domain.term.choice.reason: review

## .etymology

`review` = *re-* (again) + *view* (see) — to see again. the word already carries the retrospective
sense in plain english: you review what has passed, not what is underway. that is exactly the axis
that separates it from its neighbors here, so the domain word and the english word agree with no
gloss required.

## .evidence — the dimensional walk that forced the split

the discovery move was a **dimensional decomposition** over the repo's extant skill verbs. two
orthogonal axes turned out to explain every skill name in `repo=.this/role=any/skills/`:

- axis 1 — **tense**: retrospective (reads a record) vs present (touches a live subject)
- axis 2 — **subject**: an accumulated record, a live fault, a live entity, a driven subject

walked as a product, the cells are populated like this:

| | a record | a live fault | a live entity | a driven subject |
|---|---|---|---|---|
| **retrospective** | `review` | — | — | — |
| **present** | — | `diagnose` | `inspect` | `test` |

the retrospective row had exactly **one** occupant and no word. that empty-then-filled cell is the
evidence that `review` names a real concept rather than a preference: the other three verbs were
all unavailable, because each asserts a live subject that a log-reader does not have.

the forbidden cell is the useful one: **retrospective × live fault is empty by construction.** you
cannot diagnose a fault that already ended — you can only review its record. that impossibility is
what makes the term durable.

## .the census that grounds it

at the time of this itemization, `repo=.this/role=any/skills/` held twelve skills. the `nvim.*`
family alone spent four distinct verbs:

```
nvim.diagnose.runaway.sh    → present, live fault
nvim.inspect.embed.sh       → present, live entity
nvim.test.headless.sh       → present, driven subject
nvim.errors.review.sh       → retrospective, a record
```

four verbs on one noun is precisely the shape that invites synonym sprawl. a traveler who reached
for `nvim.errors.diagnose` would make a real claim — that the skill needs a live nvim — and would
be wrong. the verb is load-bearing, so it is itemized.

## .disputes

### dispute: show  —  raised 2026-08-11  —  status: RESOLVED (keep `review`)
- raised.by  = mechanic
- claim      = the ehmpathy role already ships `show.gh.test.errors` and `show.gh.action.logs`.
               `show` is the extant house verb for "put a record on my screen", so
               `nvim.errors.show` would follow precedent and cost no new word.
- counter    = `show` names the **output act**, not the **decision**. those two skills print a
               log verbatim; this one ranks by frequency across sessions and collapses a storm to
               one signature so the loudest defect surfaces first. that aggregate-and-rank step is
               the entire value, and `show` conceals it — a human who reads `show` expects a dump
               and will not reach for it when they want to choose a repair. it is also a
               cross-role word (`repo=ehmpathy/role=mechanic`), so to adopt it here would import
               another role's vocabulary for a different act.
- resolution = keep `review`; record `show` as a forbidden synonym **for this sense**. `show`
               remains correct in its own role for verbatim output. dispute closed.

### dispute: diagnose  —  raised 2026-08-11  —  status: RESOLVED (keep both, distinct senses)
- raised.by  = mechanic
- claim      = both verbs serve the same goal — find the defect and fix it — so one word should
               cover both, and `diagnose` already exists in two skills.
- counter    = they differ on a checkable axis: `diagnose` requires a **live** subject (it reads
               `/proc`, straces a pid, needs the fault underway); `review` requires only the
               **record** and works when every nvim has exited. to merge them would overload one
               word onto two concepts, which `rule.forbid.domain-term-ambiguity` forbids. the two
               are also complementary in practice, and the brief routes between them by that same
               live-vs-record test.
- resolution = keep both as distinct terms. `diagnose` is forbidden **as a synonym of** `review`,
               not forbidden as a word. dispute closed.

## .invariants

- a `review` operation MUST NOT require a live subject — if it needs an active process, the verb
  is `diagnose` or `inspect`, not `review`
- a `review` operation MUST aggregate — if it prints one record verbatim with no rank or group,
  the act is `show`, and it belongs to the role that owns that verb
- `review` MUST read only — the reader never mutates the record it reads (the skill guarantees
  read-only, so a review can never destroy the evidence a later repair depends on)
