# domain.term.choice.reason: measurement

## .etymology

`measure` is what the repo's prose already does everywhere — *"measured 2026-08-13"*,
*"measured on grove-1"*, `define.cry-wolf-measurements` and its `m.1`…`m.14` citations. the
word was **already canonical in practice and never itemized**, so a writer who reached for it
had no cluster to check, and drifted to `note`, `record`, or a bare `📜`.

that drift is the whole cost. a `📜` with no declared word behind it is judged by its DATE,
and a date is the one property a measurement shares with the concept it must be told apart
from.

## .the pair, and why it is a FOIL rather than a synonym

`rule.prefer.symmetric-term-pairs` asks for matched shapes on complementary labels. this pair
is complementary and deliberately **not** symmetric in status:

| | subject | verdict |
|---|---|---|
| **measurement** | the WORLD | kept, however dated |
| **changelog** | MY EDIT | cut — git already holds it |

a synonym pair would mean the two name one concept. they do not: they name two concepts that
carry the same glyph and the same date, which is exactly why one term must be canonical and
the other must be named as its foil. to leave the foil unnamed is what let ~20 changelogs sit
in the corpus dressed as measurements.

## .evidence — the audit of 2026-09-02

a full sweep of `.agent/repo=.this/role=any/briefs/` for `📜` plus the six accretion smells
(`until 202N-`, `stood here`, `used to read|be|hold|say`, `no longer`, `previously`,
`was renamed`).

```
before   ~165 hits across the corpus
after      90
```

the ~20 judgments the cut required were **all** the one question in `.the test`. the classes
it produced:

| class | instances | disposition |
|---|---|---|
| *"a `repair` row sat here and was deleted on 2026-08-10"* | 6 files | cut — the rule it restates is say-level already |
| *"this list named X as canonical until DATE"* | 4 | cut |
| *"the blocker that WAS here — resolved DATE"* | 1, say-level | cut, one line of it folded into `term=entry`'s claim |
| a **preamble** — *"the CLAIMS below were unaffected"* | 1 | cut; the blocker form named by the prose rule |
| a real result wrapped in archaeology | ~6 | **reframed** — rule first, measurement under it |
| `*.choice.reason.md` dated disputes | ~20 | untouched — carved out by the prose rule |
| `define.cry-wolf-measurements` + its gotcha | all | untouched — carved out by name |

## .the sharpest instance — a changelog that carried a LIVE falsehood

`grove.auth.github.roadmap` (465 lines) held ~150 lines of self-correction against its own
earlier drafts, opened by a preamble box: *"read this before you quote a phase"*.

⚠️ the accretion was the cheap half. buried in it, one row read `aws.params` was *"deferred by
the human 2026-08-05 (issues in use)"* — which the **say-level**
`rule.require.github-token-at-all-camp` contradicts with a rack readout, and which forbids
exactly that swap back to `os.secure`.

⇒ **accretion is not merely verbose; it is where a false claim hides.** a reader who scans a
wall of dated self-corrections stops the check on any one of them against the live rule. the
file is now ~290 lines and the row is gone.

## .disputes

### dispute: record — raised 2026-09-02 — status: RESOLVED (keep `measurement`; `record` is not forbidden)
- raised.by  = the accretion audit
- claim      = `record` is the word this repo's prose already uses most (*"it is recorded as
               one so it is not mistaken for the destination"*), so it should be canonical
- counter    = `record` names the ACT of a write-down and says no word about the SUBJECT —
               which is the one axis this term exists to fix. a changelog is a record too.
               `measurement` implies a world that answered, so the subject sits in the word
- resolution = keep `measurement`. `record` is **not** added to the forbidden list: it is a
               broader, legitimate word whose uses here are correct. it is simply not the
               canonical name for this concept

### dispute: 📜-block — raised 2026-09-02 — status: RESOLVED (a glyph is no term)
- raised.by  = the accretion audit
- claim      = the repo already has a marker for this; call the concept a "📜 block"
- counter    = the glyph sits on BOTH members of the pair. to name the concept after the
               glyph is to declare the two indistinguishable, which is the defect
- resolution = the glyph marks; the term judges. a `📜` is a claim to be classified, never a
               classification

## .see also

- `rule.require.briefs-obey-the-prose-rules` — the carve-outs and enforcement this term serves
- `term=exhibit._.choice.reason.md` — the same failure one layer out: an ARTIFACT kept past
  the argument it made, because its deletion was somebody's job to recall
