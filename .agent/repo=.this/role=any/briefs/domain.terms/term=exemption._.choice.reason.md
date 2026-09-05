# domain.term.choice.reason: exemption

## .etymology

`exemption` was already the repo's word before it was itemized: it names the concept in
`rule.require.exemptions-name-their-trigger`, and the `--bare` guard in
`git.grove.send` prints *"it is an exemption, and an exemption must name its trigger"*
at the call site. this cluster records a settled choice rather than a fresh one.

the word carries the right two implications, and both are load-bear:

1. **it is granted.** an exemption is issued by a rule, not taken against one. that
   separates it from a workaround, which is what you do when no rule would grant you
   a departure at all (`rule.require.solve-at-cause`).
2. **it is conditional.** an exemption exists relative to a condition. that is what
   makes "name your trigger" a natural demand rather than an imposition.

## .disputes

### dispute: escape hatch  —  raised 2026-08-13  —  status: RESOLVED (keep `exemption`)

- raised.by  = the human — *"you should just upgrade your tools, not use escape hatches"*
- claim      = "escape hatch" is vivid and immediately legible. it says what the flag
               DOES — you take it to get out — where "exemption" is bureaucratic and
               says only that permission exists.
- counter    = the vividness is real, and it costs a second word for one concept. the
               repo already had `exemption` in a rule name and in a live guard's
               output, so a rule named `rule.forbid.escape-hatch-as-habit` would have
               put two words for one concept into two rule filenames — the exact drift
               the glossary exists to stop.

               and the metaphors disagree in a way that matters: an *escape hatch* is
               for an emergency, taken once, under duress. that reading quietly argues
               that frequent use is the abnormality. but `--bare` is no emergency exit
               — it is a **permanently correct** route for two real conditions, and the
               defect was never that it was taken, only that it was taken where its
               trigger had gone quiet.
- resolution = keep `exemption`; record `escape hatch` as a forbidden synonym in
               contracts. it stays welcome in prose, where its vividness earns its
               keep (`rule.forbid.domain-term-synonyms` binds contracts, not comments).
               the rule was renamed from `rule.forbid.escape-hatch-as-habit` to
               `rule.forbid.exemption-as-habit` within the hour.

⚠️ note the direction of this one: the human's word was the more evocative, and the
canonical word won on consistency alone. that is the ordinary outcome and it is worth
a record — a glossary that only ever ratifies the newest word is not a glossary.

## .evidence

### the concept has a checkable invariant

> every exemption names a trigger, and the trigger is testable.

`--bare` demands a `--why`, and its help text enumerates the triggers that earn it.
that is the invariant made executable at a call site rather than left to prose — which
is what `rule.require.exemptions-name-their-trigger` asks for.

### and a second, learned the same day

> an exemption whose `--why` text never varies is a permanent condition, and a
> permanent condition is an absent feature.

measured on `--bare`: the same `--why` string was typed dozens of times in one session
for the same reason. each call was correct, and the aggregate was a tool short a
capability. the repair was `--reply` (`term=duct.reply`), and the trigger was then
retired from the guard's own help text so it could not be re-taught.

⇒ this is why the term needs both rules, not one. `rule.require.exemptions-name-their-trigger`
governs a single call; `rule.forbid.exemption-as-habit` governs the distribution.
