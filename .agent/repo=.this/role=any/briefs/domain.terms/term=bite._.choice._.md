# domain.term: bite

term.chosen   = bite
term.kind     = verb
term.synonyms.forbidden:
- work        (says only that it ran; a check that always says ✔ "works")
- pass        (names the GREEN direction — the exact half that proves the least)
- catch       (implies a defect was present; a bite is about the CHECK's power)
- fire        (says it produced output, not that its verdict discriminated)
- trigger     (same gap as fire, and already reads as an event, not a verdict)
- validate    (names what the check does at all times, not what is proven of it)
- enforce     (a rule enforces; a check bites — the enforcement is the rule's)
- assert      (what the check's CODE does; bite is about whether that assert can fail)

## .what

a check **bites** when it has been seen to go RED against a subject deliberately
broken, and GREEN against a subject known good.

so a bite is a claim about the CHECK, never about the box. the subject of "does
it bite?" is the guard; the subject of "does it hold?" is the machine.

## .the test

both directions, or it does not bite:

| direction | what it shows |
|---|---|
| green on a real pass | it is not a permanent ✋ that a reader will silence |
| **red on a real break** | it can fail at all — the half nearly always skipped |

a check proven in one direction only is half proven
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`).

## .why a word of its own

a check has two properties that are easy to conflate and cost differently:

- it **holds** — its subject is currently in the declared state
- it **bites** — it would have said so, had the subject not been

almost every green run is evidence for the first and silent on the second. the
word exists so a play can name which one it proves, and so a reviewer can ask
for the second without a paragraph.

## .refs
- .agent/repo=.this/role=any/briefs/evidence/gotcha.a-check-that-cries-wolf-gets-silenced.md
- .agent/repo=.this/role=any/briefs/evidence/rule.require.seam-claims-have-an-owner.md

## .reason
see the ref-level cluster beside this choice:
- `term=bite._.choice.reason.md` — etymology, why `pass` and `work` were refused,
  and the 2026-08-13 round that made the word load-bear across six plays
