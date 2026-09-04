# domain.term.choice.reason: exhibit

## .etymology

from the museum sense: an object on display **as evidence for a claim**. the visitor leaves
with the claim; the object stays behind in its case. that asymmetry is the whole concept —
**the value transferred to the placard, and the object is now furniture.**

it also carries the courtroom sense, and that one sharpens it further: an exhibit is entered
into a record. once the record stands, the exhibit has done its work. nobody re-enters exhibit
A at every later hearing; they cite the finding.

## .why not `one-off` — the human's own word

the human named this set as *"lots of these plbooks are oneoffs that either shoudl be in the
bundle verification steps or no longer need to exist longterm"*. that sentence is correct and
its noun is not, for a reason worth the record:

`one-off` names the **frequency of the run**. it invites the reply *"so it ran once — it is a
small file, keep it"*, and that reply is unanswerable on its own terms, because the cost of an
exhibit bears no relation to its size or its run count.

`exhibit` names the **relation to the result**. it makes the cost sayable in one line: *the
result moved, so this is now a second home for it.* and it makes the keep-case sayable too —
an artifact whose result has NOT moved is no exhibit at all, whatever its run count.

⚠️ and the frequency framing is actively wrong in both directions:
- a **tool** may have run exactly once (no fault has appeared yet) and must be kept
- an **exhibit** may have run fifty times while it was authored and is still spent

## .disputes

### dispute: one-off — raised 2026-08-11 — status: RESOLVED (keep `exhibit`)
- raised.by  = human, in the ask that started the cull
- claim      = "one-off" is the plain word, and it is what a human actually says
- counter    = it names run-frequency, which is orthogonal to the decision. a tool that has
               run once must be kept; an exhibit that ran fifty times is still spent. worse,
               "one-off" carries no reason to ACT — a small file that ran once reads as free
               to keep, and the real cost (a second home for a fact, per `term=drift`) cannot
               be derived from the word.
- resolution = keep `exhibit`; record `one-off` as a forbidden synonym. it stays the right
               INFORMAL word for the ask, and the wrong one for the test.

### dispute: dead code — raised 2026-08-11 — status: RESOLVED (distinct concepts)
- raised.by  = mechanic
- claim      = an unrun file is dead code, a concept every engineer already owns
- counter    = dead code is **unreachable or broken**. an exhibit is neither — it runs, it
               passes, and it would answer its question correctly today. that is precisely
               the hazard: dead code announces itself the moment somebody runs it, where an
               exhibit greets you with a clean ✔ over a fact that has since moved house.
- resolution = keep both. `dead code` = it cannot work; `exhibit` = it works and is spent.

## .evidence

### measurement 1 — the cull, 2026-08-11

the cull took 100 plays to 59. the split that made it decidable was no
per-file judgment, it was a **grep on the citations**:

```sh
rhx grepsafe --pattern '[a-z][a-z0-9._-]*\.play\.sh'
```

- **uncited** → an exhibit or an orphan
- **cited by a reach** → a tool. keep
- **cited by a footnote** → an exhibit. the result is already in the citing file

three of 60 were uncited. the rest classified off the wording of the line that named them,
which is why the third test condition is the one that carries the weight.

### measurement 2 — the delete that broke the map

the two `diagnose.cloud.detection.signals*` sweeps were culled **correctly** — their results
were already the probe-ladder table in `howto.detect-env-server`, complete with the measured
7ms / 1045ms imds spread. textbook exhibits.

but two live briefs still named them, and the cull repaired neither. the dangle survived a
`--play` rename sweep, because that sweep greps for **invocations** (`--play <name>`) and these
were **prose citations** (a `<name>.play.sh` path spelled out in a sentence). two shapes, one check.

⚠️ the cost is not the broken link. it is that a reader who follows a citation to no file
learns the brief is unreliable — and that doubt does not stay local to the one bad line.

⇒ hence the rule in the say file: **a delete is TWO edits.** the file goes, and every line that
named it says what became of it.

### the counter-example — an exhibit that was NOT one

`prove.git-alias-seam` and `prove.keyrack-peer-probe-bites` both looked deletable: each answers
a question that was settled months ago, and each **writes**, which `rule.forbid.repair-plays`
appeared to forbid outright.

both are **clamps**, and deletion would have been a real loss:

> `rule.require.seam-claims-have-an-owner` enforcement: *a seam check never exercised against
> a deliberate break = nitpick.*

so the break is no one-time experiment — it is a **standing requirement on every seam check**,
and these two are the reference implementations. their question is never settled, because a new
seam check can be written tomorrow.

⇒ the tell: their citations read *"the reference"*, *"the discrimination probe"* — a **reach**,
not a footnote. the third test condition caught what a read of the file's age would have missed.

📜 and the near-miss produced a second repair: `rule.forbid.repair-plays` named ONE write
exemption where two exist, so a careful reader would have deleted both as violations. that gap
is now exception 2, per `rule.require.exemptions-name-their-trigger`.

## .see also
- `term=drift` — the cost an exhibit imposes: two homes for one fact
- `term=playbook` / `term=play.prove` / `term=play.diagnose` — the artifacts this classifies
- `rule.require.bundle-as-sole-declaration` — the same repair, one layer up: remove one home
- `rule.require.wrap-cli-in-skills` — *an unnameable guard is a guard that has already failed*,
  which is the uncited half of the test
- `rule.require.clamp-edge-cases` (mechanic) — owns `clamp`, the peer this term is defined against
- `rule.forbid.repair-plays` — exception 2, written because this term's test nearly ate two clamps
