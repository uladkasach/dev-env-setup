# domain.term.choice.reason: reader

## .etymology

`reader` is the agent noun of the plainest verb in the domain: this repo's guards **read** —
a tree, an index, a config, a source file — and report what they found. the word names the
ACT and stays silent about the verdict, which is exactly the split the domain needs, because
the verdict is a separate step with its own vocabulary (`term=verdict`, `term=claim`).

the word was in daily use here long before it was itemized. `inventory.security-checks.md`
opens with *"the reader column is the point — the file-path column was the defect"*, and
that sentence is the whole reason the term matters: a row that names a FILE names where
somebody once looked; a row that names a READER names what asks the question today.

## .why `checker` lost, though it reads more naturally

`checker` is the word most people reach for, and it fails on two axes at once:

1. **`check` is already spoken for.** it is the forbidden synonym of `claim`'s act
   (`term=claim._.choice._.md`). to let `checker` in would put one root on two axes — what
   is asserted, and what asks — which is the overload
   `rule.forbid.term.addition.ambiguous` exists to stop.
2. **`checker` promises a verdict, and a reader may not have one.** `dox.verify` counts.
   `2.7.aliases`' configure.verify counts seams and compares to a declared number. a reader
   that answers *"three"* has done its whole job; the pass/fail is a caller's business.

`validator` fails the same second test more sharply — it promises pass/fail in the name.

`linter` and `scanner` fail on scope: a linter is about FORM, and a scanner sweeps with no
claim behind it. **a reader with no claim above it is a search**, and this repo has a rule
that a check must belong to a claim with an owner
(`rule.require.seam-claims-have-an-owner`).

## .why the enumerate-then-filter pair is DEFINITIONAL, not incidental

it would be simpler to say *"a reader answers a claim"* and stop. the pair is kept in the
say-level file because **the two halves are where the defects live**, measured repeatedly:

| the defect | which half |
|---|---|
| `git ls-files` for the corpus, a disk walk for the subject — 207 files apart mid-rename | two halves, two STORES (m.14, q13) |
| a count and a list built by different parses, so a padded row read as diligence | two halves, two PARSES (m.9) |
| a pattern that matched a subset, and the total was true OF the subset — so it went green | the filter, silently narrow (m.12, q11) |

a definition that says only *"it answers a claim"* gives a writer nowhere to look. one that
names the two halves tells them exactly which two reads to reconcile.

## .disputes

### dispute: checker — raised 2026-09-02 — status: RESOLVED (keep `reader`)
- raised.by  = the round-16 close
- claim      = "checker" is the ordinary English for this, and every engineer reaches for it
               first; "reader" sounds passive for what gates a ship
- counter    = the passivity is the POINT. a reader reads and reports; whether that report
               blocks is the caller's decision, and several readers here answer with a count
               and no verdict at all. worse, `check` is already the forbidden synonym of
               `claim`'s act, so `checker` would put one root on two axes.
- resolution = keep `reader`; record `checker` as a forbidden synonym. dispute closed.

### dispute: reader — raised 2026-09-02 — status: RESOLVED (distinct from `probe`)
- raised.by  = the same close
- claim      = `probe` already names a callable that asks a question and answers from
               evidence. a second term is synonym sprawl.
- counter    = they ask DIFFERENT SUBJECTS and have different failure modes. a probe asks
               the MACHINE about itself and its hazards are runtime ones — it can hang, it
               can measure the wrong process, it can be answered by a warm cache
               (`term=probe`, hazards 1-6). a reader asks a CORPUS about its members and its
               hazards are set ones — two stores, two parses, a filter narrower than the
               claim. one word for both would carry six hazards that apply to half the cases.
- resolution = keep both; the say-level file carries the two-row table so the split is read
               at a glance. dispute closed.

## .evidence

- **discovery**: the term was extracted from live use, not invented. it appears as a column
  header in the security inventory, in the enforcement lines of
  `rule.require.seam-claims-have-an-owner`, and throughout
  `gotcha.a-check-that-cries-wolf-gets-silenced`, whose thirteen questions are almost all
  questions ABOUT a reader.
- **the reach property, measured 2026-09-02**: three findings in one round, all the same
  shape — a comment claims a property the tree holds, and the reader beside it holds a
  narrower one. the guard was correct at every site; the SENTENCE was wide.
- **the false-✋ property, measured 2026-09-02**: a reader for a dataflow claim flagged
  several hundred correct lines on its first run and was deleted the same hour. two
  independent findings that round each shipped with a WARNING against a widened reader, each
  of which named what it would cost (*"well over 200 correct lines in `src/` alone"*).

## .invariants

- a reader has exactly ONE claim above it. two claims means two readers, and they will drift
- a reader's corpus and its subject come from ONE store, or the reader names both stores
- a reader is proven in BOTH directions — green on a good subject, red on a deliberate break.
  a reader never seen red is a hypothesis (`rule.require.clamp-edge-cases`)
- a reader that cannot express its claim does not get widened. the CLAIM gets narrowed
