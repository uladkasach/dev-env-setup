# domain.term.choice.reason: claim

## .etymology

from the ordinary sense: *to claim* is to assert a fact as true and make yourself answerable for
it. both halves matter here.

- **asserted** — the leaf states what the machine should be, in its own words
- **answerable** — its `verify` must either prove the assertion or say, out loud, that it cannot

that second half is why no simpler word serves. a `check` runs and returns; a **claim** is owed.
the debt is the concept, and `claim` carries it.

## .the evidence — a run that tallies NODES reads as coverage

on 2026-07-29 four runs each reported success over a defect, and every one is the same confusion
of "an act ran" with "a claim holds":

| what the run said | what was true |
|---|---|
| `✔ install_env pushed` | the payload landed at `src/src/`; three credited fixes ran nowhere |
| `✔ configure_tmux` | the conf was written; `xterm-kitty` was absent, so tmux refused anyway |
| `✔ install_robot_brains` | `rhx` installed, and throws on `--version` |
| `✔ 22 ran / 2 failed` | the two failures were named; the *unrunnable* third was invisible |

not one is a bug in an upsert. each upsert reported honestly on the only fact it knew — that its
commands returned 0. the claim we *read* ran far wider than the claim it *made*, and no word in
the vocabulary marked the difference. `claim` is that word.

### the same confusion, again in this repo's own reference implementation

the first `bundle_composite` returned `0`. so a composite landed in `BUNDLES_RUN` and printed `✔` —
and on a headless box `4.3.kitty` read as *"kitty is fine here"* while its only applicable leaf sat
skipped. `ran: 2` where one claim converged.

that earns a record because the rule against it **already existed**, by the same author, in the
same session — and the code still did it. the lesson: the defect arrives not as a bad decision but
as a node tallied out of habit. only an explicit noun for *what is worth a tally* makes the
miscount visible. hence exit `5`.

## 🛑 .the ✋ GLYPH marks three kinds of line, and only one is a claim

the section above covers a tally that counted the wrong UNIT (nodes, not claims). this one
covers a tally that counted the right unit and admitted lines that are not of it — measured
on a from-scratch grove, 2026-08-25.

a reader that keys on the glyph alone sweeps in two impostors:

| the line | what it is | countable? |
|---|---|---|
| `✋ gh is present but unauthed` | a **claim** — a phase found a fact | ✔ yes |
| `✋ grove.provision finished with failures` | a **summary** — the runner totals up | ✋ no |
| `its ✋ names the exact 'rhx keyrack set' a human owes` | **prose** — one claim's fix-text, which mentions the glyph | ✋ no |

2026-08-10 settled the second, and a name exclusion drops it. nobody had seen the third, and
it inflated `git.grove.ready.verify` rung 4 to `✋ 6` over a log that holds exactly 5.

### .why the two impostors need DIFFERENT exclusions

they differ in the one way that matters to a reader:

- a **summary** is a fixed sentence, so a name exclusion settles it once and forever
- a **prose** mention is unbounded — any fix-text may cite the glyph while it explains
  where a claim's repair lives, and each new one needs its own row

⇒ so the prose case wants a **structural** discriminator, never a lexical one. a claim's
glyph OPENS its line; a mention sits mid-sentence. one anchor admits every claim, admits
the summary (which the name exclusion then drops), and admits no fix-text:

```sh
# 👎 the glyph alone — a fix-text that cites ✋ counts as a claim
grep '✋' "$1" | grep -vc 'grove.provision finished'

# 👍 position first, then the name
grep -E '^[[:space:]]*✋' "$1" | grep -vc 'grove.provision finished'
```

a word list would grow a row per fix-text that mentions the glyph — a second declaration of
a fact the LAYOUT already carries (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.12).

### ⚠️ .the verdict was RIGHT, and the fix still matters

five claims is not zero, so rung 4 halted either way. the defect is the number printed beside
the list — and `_count_claims`' own `.why` had already named that as its entire purpose: the
count must not *"disagree with the list a reader can see right above it."*

⇒ **a tally a reader can refute by eye is how a check loses its authority**, whatever its
verdict. that is the false-✋ decay of `gotcha.a-check-that-cries-wolf-gets-silenced`,
reached through a correct halt rather than a wrong one.

📜 and it is the THIRD file to make this same miscount — `prove.phase-chain-breaks` (m.1),
then `git.grove.ready.verify` (2026-08-10), now `git.grove.operations.sh`. each repair was
correct for the impostor known at the time. a glyph that marks more than one kind of line
keeps yielding new ones.

## .disputes

### dispute: check — raised 2026-07-29 — status: RESOLVED (keep `claim`)
- raised.by  = the author, mid-refactor
- claim      = the phases are already named `verify`, and what they run are *checks*. the word is
               shorter, plainer, and already in every file header.
- counter    = `check` names the ACT; `claim` names the SUBJECT of the act. the distinction is
               load-bear precisely because the two come apart: a claim can exist with **no** check
               (exit 3 — asserted, unproven), and a check can exist that proves **no** claim
               (`command -v rhx` on a binary that throws). collapse them and exit 3 loses its
               word: a claim without a check. both words stay, at different levels — a `verify`
               runs checks; a leaf owes claims.
- resolution = keep `claim` for the assertion, `check` for the act. record `check` as a forbidden
               synonym OF `claim` — not a forbidden word, since the act still needs its name.

### dispute: guarantee — raised 2026-07-29 — status: RESOLVED (keep `claim`)
- raised.by  = the author
- claim      = every file in this repo already ends its header with a `guarantee:` block. that word
               is established; a second word for the same idea is synonym sprawl.
- counter    = they hold different scopes, and the repo already uses them so. a `guarantee:` is
               an invariant of the **file** — *"idempotent: safe to re-drive"* — true of the code
               regardless of any machine. a **claim** asserts something about **this machine right
               now** — *"the pinned kitty runs here"* — exactly what varies per box. the
               `guarantee:` blocks predate this term, and none reads correctly as a claim.
- resolution = keep both. `guarantee` = a property of the file; `claim` = a property of the machine.
               record `guarantee` as a forbidden synonym so the two are never swapped.

## .evidence

- **discovery** — scenario narrative. one walk over the four false-success rows above named
  their shared cause: every report tallied an ACT where a human read a STATE. the vocabulary
  held no noun for the state.
- **invariants** — forbidden combinations, each now enforced by
  `rule.require.grove-provision-bundles`:
  - a leaf that returns `0` when it made no claim (inapplicable) = **blocker**; it inflates `ran`
  - a composite that returns `0` rather than `5` = **blocker**; the roll tallies it for a claim it
    never made
  - a `verify` stub that returns `0` rather than `3` = **blocker**; an unproven claim is not a
    proven one
  - an unverified count absent from the roll = **blocker**; invisible debt is a false pass
- **the countable test** — an assertion earns the word `claim` when a roll can tally it and print
  it on its own line. two assertions that cannot fail independently are one claim, not two. that
  collapsed four `configure_kitty*` step lines into one phase: four writes, one claim.
