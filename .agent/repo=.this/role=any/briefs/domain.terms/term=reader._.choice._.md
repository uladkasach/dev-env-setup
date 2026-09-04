# domain.term: reader

term.chosen   = reader
term.kind     = noun
term.synonyms.forbidden:
- checker      (names the VERDICT role, and `check` is already the forbidden synonym of
                `claim`'s act — see `term=claim._.choice._.md`. to reuse it here overloads
                one word across two axes)
- linter       (tool-category jargon, and it implies STYLE. a reader answers a claim about
                security, composition, or state — never about form)
- scanner      (implies a sweep with no claim behind it. a reader exists to answer ONE
                claim, and a reader with no claim is a search)
- validator    (promises a pass/fail. a reader may answer with a COUNT, a list, or a
                comparison, and the verdict is a separate step)
- grep         (names one implementation. a reader may be a `grep`, a `git ls-files`, a
                `cmp`, or a walk — the word must outlive the tool)

## .what

the one callable that asks a **claim**'s question of a corpus, and answers it from evidence.

a reader does two things, always, and the pair is what makes it a reader:

1. it **enumerates a corpus** — the set the claim is about
2. it **filters a subject** out of that corpus — the members the claim names

> `dox.verify` enumerates every tracked file and filters the lines that hold an identifier.
> `2.7.aliases`' configure.verify enumerates `ductwork.sh` and filters the registry joins.

## .reader ≠ probe

they are DISTINCT, and both are kept:

| | asks | answers with | store |
|---|---|---|---|
| **probe** | the MACHINE, about itself | yes / no / could-not-tell | runtime state |
| **reader** | a CORPUS, about its members | a count, a list, a comparison | a tree, an index, a file |

a verify often holds both: a probe for *"is it installed?"* and a reader for *"does the
source still say what the comment claims?"*

## 🛑 .a reader's REACH bounds the claim above it

the property this term exists to carry, and the one this repo re-learns:

> **a claim is only as wide as its reader can reach.** the sentence above a reader may be
> true of the tree today and still be a claim the reader cannot hold — and no run says so.

measured 2026-09-02, and it was the entire yield of one round:

```
claimed:   "every path join goes through here"
reached:   the joins that name the dir LITERALLY, on one line
```

a fifth join that aliases the dir first counts zero, the total holds, and the row goes green
through the exact regression it is shaped for.

⇒ so write the claim to the reader's reach, and say plainly that any wider sentence is a
human's to renew (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11).

## 🛑 .a reader's two halves must come from ONE STORE

the corpus and the subject are two reads, and two reads are free to disagree. `git ls-files`
reports the index exactly; a disk walk reports the disk exactly; a rename in flight puts them
apart for hours.

⇒ name the store, or read both and demand they agree (q13, m.14).

## ⚠️ .a reader that reddens on correct code is WORSE than an absent one

a false ✋ at scale does not stay a false ✋ — it decays into a silenced check, and it takes
the trust in every reader beside it along with it.

measured 2026-09-02: a reader written to hold a **dataflow** property (*"this value came
from off the box"*) flagged several hundred CORRECT lines across 15 files on its first run,
and was deleted the same hour. no grep over source can see where a value came from.

⇒ when a property has no expressible reader, the honest close is to **narrow the CLAIM** —
never to widen the reader until it bites correct code.

## .refs

- `.agent/repo=.this/role=any/briefs/creds/inventory.security-checks.md`   # `.the reader column is the point`
- `.agent/repo=.this/role=any/skills/wire.verify.sh`                 # a source reader over a corpus
- `.agent/repo=.this/role=any/skills/dox.verify.sh`                  # enumerate tracked, filter identifiers
- `src/grove.provision/2.shell/2.7.aliases/configure.verify.sh`      # the counted-join reader
- `.agent/repo=.this/role=any/briefs/evidence/gotcha.a-check-that-cries-wolf-gets-silenced.md`  # q11, q13, m.9, m.14

## .reason

see the ref-level cluster beside this choice:
- `term=reader._.choice.reason.md` — why `checker` lost despite its natural read, why the
  enumerate-then-filter pair is definitional rather than incidental, and the dated evidence
  that a claim outruns its reader in silence
