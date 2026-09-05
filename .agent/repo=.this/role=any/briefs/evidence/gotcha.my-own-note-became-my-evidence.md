# gotcha: a claim I wrote down became the evidence for itself

## .what

a fact arrives from outside — a relayed sentence, a teammate's reply, a doc. you write it
into a file. later you read that file, treat it as a source, and build on it.

the loop closes silently. by the third hop the claim reads as **repo-attested** and its only
ground is that you typed it once.

## .why it is worse than a plain unverified claim

`rule.require.trust-but-verify` covers the claim you *know* you inherited — a summary, a
prior session, a diagnosis. you can feel the seam, so you can choose to check it.

this variant hides the seam. after one hop the claim wears your repo's own voice:

| hop | where it sits | how it reads |
|---|---|---|
| 0 | a human relays infra's sentence | hearsay, obviously |
| 1 | you write it into a brief | **a repo brief states it** |
| 2 | you cite the brief | a cited fact |
| 3 | you build a contract on the citation | settled vocabulary |

no step feels like an invention, and the last step is indistinguishable from good practice —
you *did* cite a source. the source was you.

## .measurement — `git.grove.rebuild`, 2026-08-09

a human relayed infra's reply, which named `git.grove.rebuild --mode apply` as the command
that replaces a grove's root volume. within one session:

1. it went into `handoff.infra.grove-user-split.md` as the cost of ASK 2
2. that brief was cited as evidence when a **domain term** was itemized for the verb —
   `term=grove.rebuild._.choice._.md` plus its `.reason`, with a forbidden-synonym list
3. a play was **renamed** to conform to the new term, and a resolved dispute was filed whose
   whole counter-argument was *"the play gates an OPERATION, and the operation is
   `grove.rebuild`"*
4. a progress round was written that celebrated the term as its keeper

**no such skill exists.** the grove family is `del get infra.operations list pull push
push.verify read send set stop trust.gen wake`. one glob disproves the whole chain, and it
was run only when a human asked *"what is grove.rebuild?"*

⚠️ the tell that was available throughout and went unread: **every reference was mine.** a
grep for the verb returned the handoff I wrote, the term files I wrote, the play I renamed,
and the progress entry I wrote. a claim with real ground has at least one reference somebody
else put there.

## .why the ordinary guards missed it

- **the artifacts were well-formed.** the term cluster had a proper `.reason`, a
  forbidden-synonym table, a dated dispute with claim/counter/resolution. form is no evidence
  of ground.
- **it was cited, not asserted.** step 2 pointed at a real file with a real line number.
- **the rule that would have caught it was fresh in mind.** two rounds earlier `camper` had
  been *deferred* on exactly this boundary — "the authorship is not ours yet" — and the
  precedent went unapplied to the identical case.

## .the test

before a claim about a subject **outside this repo** earns a contract — a term, a skill name,
a rename, a play — ask:

> **who put the first reference there, and can I reach it without a hop through my own text?**

- an upstream artifact, a real file, a command that answers → grounded
- every path leads back to a file I authored this session → **unproven, whatever its form**

for a claim that names a callable operation, the check is nearly free:

```sh
rhx globsafe --pattern '.agent/repo=.this/role=any/skills/<family>.*'
```

## .the cheap habit

when you write down a fact you did not verify, **mark it at the moment it lands.**

```md
📌 relayed from infra 2026-08-09, unverified — `git.grove.rebuild` matches no skill here
```

one line, written while the seam is still visible, is what stops hop 2. the marker survives
into the file; your memory of where the sentence came from does not.

## .enforcement

- a domain term itemized for an operation this repo does not declare = **blocker**
  (`rule.require.domain-term-itemization` — the anchor is a *declared* dobj/dop)
- a rename, skill, or contract bound to an unverified external name = **blocker**
- an unverified external fact written into a brief with no marker = **nitpick**

## .see also

- `rule.require.trust-but-verify` — the general form; this is its self-referential variant
- `rule.require.domain-term-itemization` — a term's anchor must be *declared*
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the near neighbour, where the ROWS are true
  and the set or the consultation is partial
