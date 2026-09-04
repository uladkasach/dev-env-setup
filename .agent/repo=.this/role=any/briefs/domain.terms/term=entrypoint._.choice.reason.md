# domain.term.choice.reason: entrypoint

## .etymology

a compound already standard in software for *the place control enters a program* — `main`, a
lambda handler, a cli's first line. this repo widens it one step: the place **bytes** enter,
not just control. the widened sense keeps the property that made the original useful — an
entrypoint is a PLACE, so you can point at it, list it, and count it.

`attack surface` was the natural competitor and it lost on exactly that property. it is a mass
noun. you cannot enumerate a surface or say a repo has eleven of them, so a reviewer who
reports on "the attack surface" has reported a mood. the whole defect this word exists to fix
is a set nobody counted, and a word that resists a count reproduces the defect it names.

## .disputes

### dispute: attack surface — raised 2026-09-02 — status: RESOLVED (keep `entrypoint`)
- raised.by  = the round-22 dispatch review
- claim      = "attack surface" is the industry-standard phrase; a reader anywhere would grasp
               it with no gloss, and `rule.forbid.domain-term-synonyms` prefers the word the
               domain already speaks.
- counter    = it is a MASS noun and this repo needs a COUNT one. the entire lesson of m.12 is
               that a count is a claim about a set, and a set is only as big as the reader's
               reach — so the round's deliverable must be an enumerable list, and its unit
               needs a singular. "eleven entrypoints" is a checkable claim; "the attack
               surface" is not. the industry phrase names the same territory and cannot name
               a member of it.
- resolution = keep `entrypoint`; record `attack surface` as a forbidden synonym. it stays
               legal in PROSE that describes the territory as a whole, per
               `rule.forbid.domain-term-synonyms`'s comment carve-out — the forbid is on
               contracts, and the enumeration's unit is a contract.

## .evidence

### the measurement — 2026-09-02, and a human's question forced it

class 5 was added after 21 rounds, all of which took the laptop as their vantage. the dispatch
composed for it inherited §3's heuristic unchanged:

> So your question is never *"what is unguarded?"* — it is:
> **for each guard, what exactly does its comment CLAIM, and what does its code REACH?**

three reviewers were launched under it. then the human asked:

> *"so does it specifically get them to search for ingress entrypoints?"*

and the answer was **no — the dispatch told them not to.**

⇒ the heuristic is sound and its SCOPE was never written down. it was learned across 21 rounds
aimed at surfaces somebody had already reviewed, where a guard is nearly always present and
merely weaker than its comment. on ground nobody has swept, no pressure ever forced a guard to
exist, so absence is the live hypothesis — and the round was explicitly steered off it.

### why an enumeration, and not a wider heuristic

the repair could have been one sentence: *"also look for absent guards."* that fails for the
same reason a hand-written asset list fails — it asks a reviewer to notice a gap, and a gap is
precisely what a reader cannot notice. an ENUMERATION inverts the burden: you derive the set
first, then ask the claim-vs-reach question of each member. a seam missed by the derivation is
still missed, but the derivation is a mechanical step somebody can audit, re-run, and inherit.

⚠️ hence the clause that the set is DERIVED, never typed — and that the dispatch's own hint
list is explicitly disclaimed as non-authoritative. a typed list handed down as the set would
re-create m.12 inside the very deliverable meant to close it.

### the residue, stated

**no reader enforces this.** the enumerate-first pass is prose in a dispatch, obeyed by whoever
reads it. a clamp cannot express it, because "did the reviewer enumerate?" is a fact about a
report, not about this tree. the honest close is that the entrypoint set for class 5 will be a
REPORT artifact, and the next round inherits it from the ledger — with all the decay a written
set carries (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13).

## .see also
- `term=ingress._.choice._.md` — the event that arrives through a seam
- `term=reader._.choice._.md` — the derived-vs-typed constraint this leans on
- `rule.require.one-command-provision` — *"a hand-written list cannot report the member nobody added"*
