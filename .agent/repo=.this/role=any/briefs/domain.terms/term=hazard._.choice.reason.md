# domain.term.choice.reason: hazard

## .etymology

a **hazard** is a source of danger that is simply THERE — a road hazard, a fire hazard. it names
a condition, never an accident. the word carries the whole distinction in its ordinary sense:
you do not say "a hazard happened", you say "a hazard EXISTS". that present tense is exactly
what separates it from `gotcha`, which is a story about a moment.

it also matches how the corpus already spoke: `howto.review-public-repo-hazards` enumerates
*"the six sources of risk a public repo carries"* — sources, not incidents.

## .disputes

### dispute: `gotcha`  —  raised 2026-09-03  —  status: RESOLVED (both, split by tense)

- raised.by  = the port of `brains.auth` from main, which filed 9 briefs under a `hazard.`
               prefix into a dir whose `briefs/.readme.md` prefix table lists `gotcha.` and not
               `hazard.`
- claim      = `gotcha.` is the declared prefix. `.readme.md` defines it as *"a trap, with the
               measurement that found it"*, and every one of the 9 is a trap. one prefix per
               concept is the whole point of `rule.forbid.domain-term-synonyms`, so the 9
               should be renamed and the ~15 by-name citations in `src/brains.auth.sh` updated
               to match.
- counter    = they are not one concept. read the `.what` of each of the 9 and the split is
               plain: every one states a property in the PRESENT tense — *"any value handed to
               an external binary as a command-line argument lands in `/proc`"*, *"a regression
               clamp is code, so it can carry the defect class it guards"*, *"every number
               comes from one undocumented endpoint"*. none is a story. by contrast every
               `gotcha.` on this branch is a dated measurement: `gotcha.pipefail-grep-q`,
               `gotcha.while-read-drops-the-last-line`, `gotcha.a-check-that-cries-wolf-gets-silenced`.
               and `.readme.md`'s own definition of `gotcha.` — *"with the measurement that
               found it"* — is what settles it: a measurement is REQUIRED of a gotcha, and
               several of the 9 have none, because the property has never fired.
               `hazard.claude-usage-endpoint-is-undocumented` is the sharpest case: the
               endpoint has not broken, so there is no measurement to carry, and to file it as
               a gotcha would demand evidence that does not exist —
               `gotcha.my-own-note-became-my-evidence` in a fresh costume.
               ⚠️ and `hazard` is NOT an import. two briefs authored on this branch
               (`nvim.hazard.async-refresh-on-quit`, `kitty.hazard.copy-forward-regressions`)
               already used it before the port. the dir's own INDEX was behind its corpus.
- resolution = keep both, split on tense. `gotcha.` = it bit, with the measurement.
               `hazard.` = it holds, as a property. add `hazard.` to the prefix table in
               `briefs/.readme.md`, which is where the gap actually was. no rename, and no
               citation touched. dispute closed the day it was raised.

### 📌 dispute: prefix or infix  —  raised 2026-09-03  —  status: OPEN

- claim      = the two branch-native uses are INFIX (`nvim.hazard.…`, `kitty.hazard.…`) and the
               11 others are PREFIX (`hazard.…`). one word, two shapes, one dir.
- counter    = the infix subject (`nvim.`, `kitty.`) is a leftover of the pre-restructure FLAT
               brief dir, where a filename prefix was the only way to group at all. both now sit
               in a subject directory (`desktop/nvim/`, `desktop/term/`) that already carries
               that subject, so the infix restates the path. ⇒ the prefix form is likely
               correct and the two are stragglers.
- why open   = the same argument applies to `nvim.md`, `nvim.minimap.spec.md`,
               `system.power.spec.md` and their neighbours, so it is a **directory-wide rename
               question about the subject prefix**, not a hazard question. it must be settled
               once for the whole corpus, never twice. contracts keep both shapes meanwhile —
               the corpus reads correctly either way, since `hazard` sits in the name in both.

## .evidence

- **shape** — the split was tested against the corpus, not asserted. every `hazard.*` `.what`
  reads in the present tense and names a property; every `gotcha.*` names a dated event. that
  is 11 files on one side and the extant gotcha family on the other, with no straddler found.
- **the one-way arrow** — a hazard can earn a gotcha (a property fires → you own a
  measurement); a gotcha can never become a hazard, because a measurement does not un-happen.
  a genuine synonym would be symmetric, so the asymmetry is the proof the split is real.
- **the cost of the merge** — a forced rename would demand each of the 9 carry a measurement to
  satisfy `gotcha.`'s own definition, and several have none. the pressure to invent one is the
  exact defect `gotcha.my-own-note-became-my-evidence` records.
- **precedent in this dir** — `play.verify` / `play.prove` / `play.rollback` are split on the
  same kind of axis (what verdict it asserts, which direction it writes) rather than merged
  under one word. one axis, several members, each named — this is that pattern.
