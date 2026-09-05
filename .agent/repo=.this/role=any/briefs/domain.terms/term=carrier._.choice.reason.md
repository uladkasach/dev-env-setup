# domain.term.choice.reason: carrier

## .etymology

freight. a carrier moves your goods and the goods are meant to arrive unchanged by the
choice — you do not expect a different parcel because one truck was available and another
was not. that expectation is exactly the invariant this pair has broken three times, so
the word carries the demand.

chosen over:

| rejected | why |
|---|---|
| `transport` | the word is right for the ACT and wrong for the MEMBER. `git.grove.push`'s header says "two transports" and then must add "the pair splits by need" to recover the sense. one carrier, one transport act; `--via` names a carrier |
| `backend` | implies a service on the far side. tar runs on the near side too, and neither is a service |
| `method` / `strategy` | reads as "a different way to do it", which is the belief the term exists to refuse. a carrier pair has ONE way; only the tool differs |
| `mechanism` | this repo's word for how code works generally; too coarse to name a member of a declared pair |

## ⚠️ .why `transport` is not merely a near-miss

`git.grove.push`'s own header records the cost of the loose word:

> the two branches disagreed on LAYOUT, so one command had two outcomes, split by which
> tool the box happened to hold

when the pair are "two transports", two outcomes read as two implementations, which is
what an engineer expects of two implementations. when they are two CARRIERS of one
policy, a divergence reads as the defect it is.

## .evidence — three disagreements, one pair

| measured | what disagreed | the cost |
|---|---|---|
| 2026-07-29 | LAYOUT — rsync copied the DIRECTORY into the target, tar copied its CONTENTS | `--from src --into …/src` wrote a shadow copy at `src/src/` and printed `cowabunga! pushed` |
| 2026-08-31 | LINK POLICY on pull — tar refused every link member, rsync `-az --safe-links` landed an in-tree one plus every device node | a laptop HAS rsync, so the branch every real pull took was the lightly-guarded one |
| 2026-09-01 (r8 B1) | WHICH STREAM names a refusal — push read rsync's notice off stdout and had been seen red; pull read stderr | pull's whole `✋ refused` block was unreachable, and the grove's filenames reached the terminal raw |

⇒ read the three together. each was found by a different route and every one is the same
sentence: **a pair that splits by AVAILABILITY must not split by BEHAVIOUR.** the third
is the sharpest, because the correct answer was already written down in the other holder
and had already been proven.

## .disputes

### dispute: transport — raised 2026-09-01 — status: RESOLVED (keep `carrier`)
- raised.by = the author of this cluster
- claim = `transport` is what `git.grove.push`'s header already says, at length, and a
  rename of a settled word is churn
- counter = the header uses it in TWO senses in one block — "two transports" (the tools)
  and "the transport that ran" (the act) — and the ambiguity is load-bear here, since the
  whole rule is that the ACT must be identical while the TOOLS differ. one word for both
  makes the rule unstateable
- resolution = `carrier` names the member; `transport` keeps the act. the extant prose in
  `git.grove.push` is left alone — it is a measurement's record, and a sweep of settled
  prose is the blocker `rule.prefer.wickup-touched-prose` names. new contracts take
  `carrier`

## .see also

- `term=holder._.choice._.md` — a carrier pair is the canonical two-holder case
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9
- `rule.require.identical-bundle-composition` — one declaration, many obeyers
