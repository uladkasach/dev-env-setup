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

### dispute: carve-out  —  raised 2026-09-07  —  status: OPEN

- raised.by  = the round that added a third by-path site to `rule.forbid.the-driver-by-path`
- claim      = `carve-out` and `exemption` name one concept, so the pair is
               `rule.forbid.domain-term-inconsistency`'s exact shape: two words, one
               concept, **no canonical judgment between them**. and the inconsistency is
               not marginal — `carve-out` is the primary word in the very rule that
               governs exemptions:

               > *"when you write a **carve-out** — an exemption from a check, or a scope
               >  that covers less than the [rule it serves]"*
               >   — `rule.require.exemptions-name-their-trigger:5`

               ⇒ so a reader meets `carve-out` first in the rule, and `exemption` first
               in the glossary. neither points at the other.

- counter    = they may be **genus and species** rather than synonyms, and that case
               rests on the quoted line itself, which grants `carve-out` TWO senses:

               | word | what it may name |
               |---|---|
               | `exemption` | a sanctioned departure from a DEFAULT, per this cluster |
               | `carve-out` | that, **or** a SCOPE that covers less than its rule |

               a narrowed scope grants no departure to anyone — it states that the rule
               reaches less far than a reader would assume. that is a different act, and
               `exemption` does not name it.

               ⚠️ and step 1 of `rule.forbid.domain-term-inconsistency` is exactly this
               check — *"confirm they are truly one concept, not a real distinction
               concealed under a shared shape"*. the distinction here is plausible and
               unproven, which is why this is OPEN rather than resolved.

- resolution = **RESOLVED 2026-09-08, by the enumeration this entry itself prescribed.**
               `exemption` stands canonical; `carve-out` joins the forbidden list. the
               second sense is REAL and earns no coinage yet. the account is below.

⚠️ **and no rewrite is owed either way.** `rule.forbid.domain-term-inconsistency` says
conform the other uses **or leave them until disturbed** — there is no forced mass-rewrite,
and `carve-out` sits in ~28 sites across the briefs.

### the enumeration — run 2026-09-08, 41 sites read

sorted by the test this entry named: *departure-from-a-default* vs *narrowed-scope*.

| bucket | count | examples |
|---|---|---|
| **departure** — a named case is permitted to disobey a rule | ~39 | the two by-path sites · the rollback + probe exceptions · the three prose `📜` records · the bootstrap's stand-alone status |
| **narrowed scope** — the rule reaches less far than a reader assumes | **2** | `rule.forbid.domain-term-synonyms`' comment clause · arguably `repair-plays` exception 2 |

⇒ **both buckets fill, so they are two concepts** — and the discriminator is not a judgment
call. it is mechanical:

> **an exemption has a TRIGGER that could void it. a scope boundary has none, and needs none.**

*"if `rhx` becomes reachable on that far side, the by-path allowance is void"* — a real,
checkable trigger. now try it on the comment clause: **no observation could void it**, because
nobody was granted a departure. that rule's subject is a contract, and a comment was never in
scope at all.

### 🛑 so why `carve-out` still LOSES

two filled buckets prove a second CONCEPT. they do not prove the second concept should take
the contested word — and it must not:

1. **~39 of 41 sites use it for the departure sense**, which is `exemption`'s. so as it stands
   the word is a synonym in nearly every site and an overload in the rest — the worse of the
   two failures (`rule.forbid.domain-term-ambiguity`).
2. **n = 2.** `rule.require.enumerate-before-you-name`: a word tested against two instances has
   been tested twice. the concept is real; its vocabulary is unearned.

⇒ so `carve-out` is forbidden, the second sense is recorded here rather than named, and a
coinage waits for a third instance. extant sites are conformed on contact, never swept.

### 🔴 what this enumeration turned up — a rule is MIS-SCOPED

`rule.require.exemptions-name-their-trigger` binds both senses in one breath:

> *"when you write a **carve-out** — an exemption from a check, **or a scope that covers less
> than the whole** — it must name … its trigger"*  — `:5`

and then:

> *"if you cannot name a trigger, you do not have an exemption — you have a guess with a
> citation format."*  — `:48`

⇒ **a principled narrowed scope has no trigger by construction, so those two lines condemn
it.** an author who obeys them must either invent a fake trigger for a boundary that needs
none, or read a correct scope statement as a defect.

⚠️ the rule is not wrong about the case it was written for. its `implicit` row (`:32`) catches
a scope stated as an ENUMERATION, which genuinely does hide exemptions — that is the real
hazard and it is well named. what over-reaches is `:5`'s second clause plus `:48`'s blanket,
which together sweep in a scope stated as a PRINCIPLE.

⇒ recorded, not repaired: the fix belongs to that rule, and this cluster's job is to say which
concept is which.

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
