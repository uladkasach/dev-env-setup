# domain.term: entrypoint

term.chosen   = entrypoint
term.kind     = noun
term.synonyms.forbidden:
- attack surface  (names the whole SET at once, so it can never be enumerated or counted. the
                   defect this term exists to fix is an uncounted set — a word that resists a
                   count reproduces it)
- vector          (the PATH an attacker walks, end to end. an entrypoint is its first step —
                   one seam, nameable at a file:line)
- input           (far too broad: every argument to every function is an input. an entrypoint
                   admits bytes chosen REMOTELY)
- interface       (a contract this repo publishes on purpose. an entrypoint is often accidental)
- endpoint        (an http route, and only that. most entrypoints here are neither http nor routes)
- ingress point   (a compound of `term=ingress`, which is the EVENT. this is the SEAM — see the
                   pair below)
- door            (a metaphor, and it invites "locked/unlocked" when the real question is what
                   the guard REACHES)

## .what

an **entrypoint** is one seam where remote-chosen bytes reach a subject at all — a listener,
a fetch, a file read, an accepted value.

it is a place, nameable at a `file:line`, and therefore **countable**. that is the whole point
of the word.

## .the pair it completes

```
entrypoint  → the SEAM.   a place. countable, enumerable
ingress     → the EVENT.  bytes gain influence through such a seam
```

so every ingress arrives through an entrypoint, and most entrypoints admit no ingress —
because a guard holds. the two are not the same, and one is not a grade of the other.

## 🛑 .why the word had to exist — an unlisted seam has no guard to be weaker than

📜 measured 2026-09-02. 21 rounds ran under one heuristic:

> **THE GUARD IS RARELY ABSENT. IT IS WEAKER THAN ITS OWN CLAIM.**

it is true, and it was learned entirely on ground somebody had already reviewed. it says the
round's question is *never* "what is unguarded?" — and on a class no round has ever swept,
that **inverts**: no pressure ever forced a guard to exist there.

⇒ so a first sweep owes an ENUMERATION before it owes any claim-vs-reach audit:

> **an entrypoint nobody enumerated has no guard to be weaker than its claim, and no round
> can report what it never listed.**

⚠️ and the enumeration is a deliverable **even when every entry is guarded.** it is the most
durable output a first sweep produces: the next round inherits the set instead of a
re-derivation of it, and a set no one wrote down is one no one can notice a new member of
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12 — a count is only as big as the
reader's reach).

## ⚠️ .an entrypoint set is DERIVED, never typed

a hand-written list "cannot report the member nobody added"
(`rule.require.one-command-provision`). this repo has measured that defect three times in one
day, so an entrypoint list handed to a reviewer is a HINT, never the set — and the dispatch
says so in those words: *do not accept any list somebody typed, this one too.*

## .refs
- `.agent/repo=.this/role=any/skills/redteam.round.sh`   # §3 — the enumerate-first pass
- `.agent/repo=.this/role=any/briefs/creds/howto.run-a-redteam-round.md`
- `term=ingress._.choice._.md`                           # the EVENT this seam admits
- `term=reader._.choice._.md`                            # why a derived set beats a typed one

## .reason
see the ref-level cluster beside this choice:
- `term=entrypoint._.choice.reason.md` — the etymology, why `attack surface` lost, and the
  2026-09-02 measurement that made the word necessary
