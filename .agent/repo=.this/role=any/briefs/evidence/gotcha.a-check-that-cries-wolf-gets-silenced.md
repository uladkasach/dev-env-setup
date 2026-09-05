# gotcha: a check that reports a false ✋ is worse than one that reports a false ✔

## .what

a **false ✔** passes while what it guards is broken (`rule.forbid.failhide`,
`gotcha.pipefail-grep-q`, `gotcha.while-read-drops-the-last-line`).

a **false ✋** is its mirror and the more corrosive half: a check that reports a failure
against a subject that plainly works.

## .why it is the worse half

a false ✔ fails **once**, silently, on the run where it mattered. a false ✋ fails **every
run**, loudly, on runs where it did not. the cost is what a human does next:

1. the check goes red against evidence in the same output that it is wrong
2. the human learns that this check lies
3. the human silences it, loosens it, or stops to read it at all
4. it is now a false ✔ — and it took its credibility with it

so a false ✋ does not stay a false ✋. it **decays into** a false ✔, and it takes
the reader's trust in every check beside it along with it.

## .the measurements — the index

each question in `.the test` below is tagged with the measurement that taught it. **every one
is written up in full in `define.cry-wolf-measurements`** — the output it printed, the cause it
turned out to have, and the repair that closed it.

| m | what the check got wrong |
|---|---|
| 1 | counted a runner's SUMMARY glyph as if a phase had spoken |
| 2 | a third file changed the SHAPE of the text between the check and its subject |
| 3 | a DIAGNOSE gathered true evidence that was incomplete — a rule read without its exemption |
| 4 | verdict and evidence were both right; a summary underneath named the wrong SUBJECT |
| 5 | the probe measured a world its own FIXTURE failed to build |
| 6 | it cited a true, in-repo sentence — about a DIFFERENT claim than the one it asks |
| 7 | one pattern spanned two claims, and the correct value is OPPOSITE in each |
| 8 | the tokenizer tore prose in half, so an `echo` reached the pattern as a bare call |
| 9 | one set, two readers — the sweep was right and the audit beside it over-reported 5× |
| 10 | the correction QUOTED the dead pointer it corrected, and so re-created it |
| 11 | the fixture was obeyed exactly, and the claim it encoded was false of this tree |
| 12 | the pattern matched a SUBSET, and the total was true of the subset — so it went green |
| 14 | the reader was right and the SUBJECT had two stores; index and tree disagreed, silently |

⚠️ m.3 sits after m.4 in the write-up because it was recorded late. the number is a stable
citation, never a sequence.

⚠️ **m.13 is absent from that table on purpose** — it sits below, in this file, because it names
no defect in a reader's logic and so yields no question in `.the test`.

## .the test

before you trust a check that just went red, ask these thirteen, in order. each reaches a
defect the ones before it cannot. the tag names the measurement that taught it.

**q1 (m.1) — does the output it printed as evidence agree with its verdict?**
if the two contradict on one screen, suspect the check first. print what you observed, not
only what you concluded (`gotcha.while-read-drops-the-last-line`, `.the lesson beyond the newline`).

**q2 (m.2) — does the evidence name a difference in the SUBJECT, or in a tool it called?**
a diff over raw output holds both; only the first is a defect. a verdict faithful to its
evidence is still worthless when the evidence was never the state.

**q3 (m.3) — did this row consult the exemption, or only the general rule?**
q1 and q2 assume a verdict, so neither reaches a `diagnose`. a `·` earns trust when the row
names what would have made it a `✔` AND confirms that absent.
`apparmor_restrict_unprivileged_userns = 1` is the general rule; the per-binary profile is
its exemption; a row that reads one and not the other is unproven however true it was.

**q4 (m.4) — does the sign-off line claim more than its rows can support?**
a check that halts at one of several rungs cannot name a single subject unless the rungs
share one. say which rung spoke, or say none — a generalization is not free just because
every line above it was correct.

**q5 (m.5) — did the fixture this probe built actually take — all of it?**
a setup that takes in part is worse than one that fails outright: the run completes, every
row is true, and the verdict is about a world nobody meant to create. read the probe's own
echo of its subject before its verdict.

**q6 (m.6) — what exactly does this check claim, and is the rule I cited about THAT claim?**
one call answers two questions differently, so a true, authoritative, in-repo sentence can
condemn nine correct sites when it settles the other half.
⇒ ask this **before** you change a reader, not after it goes red. its companion is cheap:
when you change what a reader classifies, add a fixture arm for that shape in the same edit.

**q7 (m.7) — is there a site this pattern matches where the correct value is DIFFERENT?**
if yes, the pattern must carry the discriminator, because one verdict cannot serve two claims.
`timeout 60 pnpm bin -g` and `timeout 900 pnpm install` are one text to a reader keyed on
`timeout <n> <tool>`, and the right `<n>` is opposite in each.
⚠️ this false ✋ does the most damage, because its `fix:` line is specific, plausible, and a
regression. a bare complaint gets ignored; a named fix gets applied.

**q8 (m.8) — what did the reader hand this pattern, and is that still what the file says?**
a reader that splits, strips, or normalizes text has a second place to be wrong, invisible in
the pattern. `echo "… && corepack install …"` is prose in the file and a bare
`corepack install` by the time a first-word check reads it.
⚠️ the arm for the shape may already exist and pass **for the wrong reason**. ask whether an
arm would still pass if the property it names were absent — if yes, it proves a property
nobody implemented.

**q9 (m.9) — how many readers does this file point at one set, and do they share a tokenizer?**
a check that reports violations AND lists exemptions has cut one set into complementary halves.
written independently they drift, because each half looks correct alone — and the cheaper half
is always the one that stays a plain grep.
⚠️ the drift surfaces as a **false `·` in an audit**, the quietest failure in this brief: an
audit claims no verdict, so a reader has none to distrust, and a padded list reads as
diligence. arms belong on both halves, in the same edit.

**q10 (m.11) — is this arm's sentence true of THIS tree, or of the tree I borrowed it from?**
a borrowed claim arrives dressed in a ✔, because the arm passes the moment the reader obeys it.
a fixture proves obedience; only the LIVE rows say whether what was obeyed is right. read both
in the same run; accept neither alone.

**q11 (m.12) — in how many forms is this subject written, and which does the pattern match?**
a count is a claim about a set, and a set is only as big as the reader's reach. `170 cited
paths` reads as *the corpus* and means *the part I matched*; a row nobody reads produces no row.
⚠️ **no fixture answers this.** an arm plants only a shape its author can see, so a fixture
written by whoever wrote the reader inherits that reader's blind spot verbatim. nor does a
**floor** — one calibrated on a blind first read ratifies the blindness as its baseline.
⇒ what answers it is a **planted row in the LIVE subject**: one dead pointer, one fabricated
package, one impossible sha, in the form the corpus uses. if the count does not move, the
reader cannot see that form, and every row written that way has been unproven since day one.

**q12 — is this check's remembered state still ABOUT the subject in front of it?**
q1-q11 interrogate a check that READS on the spot. a check that REMEMBERS keys its note on
some field, and the defect is a key that outlives its subject. `git.grove.provision` keyed "an
apply already ran here" on the grove **NAME**, and a name survives a rebuild. so on 2026-08-30
a plan against a box built eleven minutes earlier reported an apply driven at `07:05:47Z`, on
an instance terminated at `07:04:28`.
⇒ the repair is never a fresher note. **ask the subject**, which holds the only copy that dies
with it — here, the apply's own log on that disk. a note kept beside a subject is the m.9 shape
one step out: one fact, two holders, the local one free to drift with no signal.
⚠️ the repair has its own trap: a remote read has **three** answers. the first cut collapsed
"the duct gave no verdict" into "no prior apply" — a false ✔ introduced by the fix for a false
✋. the full account sits in `define.provision-defect-shapes`.

**q13 (m.14) — which STORE did this count consult, and does the subject have more than one?**
q1-q12 all interrogate a reader. this one grants the reader is correct and asks about the
SUBJECT: `git ls-files` reports the index exactly, `tree` reports the disk exactly, and a delete
that reached one of them makes the two disagree with no signal. a count is a claim about a set,
and a set with two stores has two true answers.
⇒ name the store, or read both and demand they agree. ⚠️ a third store reads from no command at
all — the record a reader keeps beside the set — which is q12's trap one step out.

## 🛑 .measurement 13 — a check NOBODY RUNS decays into a false ✋ on its own

every other measurement names a defect in a check's LOGIC, or in the subject it reads. this one
needs no defect at all: a check
that goes unrun **rots against a moving tree**, and every day it sits idle raises the odds
its first verdict argues against correct code.

measured over a set of 39: **9 red on their first roll, and at least 4 of the 9 were the
CHECK gone stale rather than the tree gone wrong.** two of the four shared one cause —
`2.8.tmux`'s tpm pin moved into the bundle's `_.sh`, and two independent readers never
followed (one keyed on `local`, the other cut at a `\` continuation). m.9's shape, aged.

⇒ **a check earns its keep by RUNNING, not by sitting in a directory.** a set that argues
against correct code half the time does not get read carefully; it gets silenced — the
corrosive half this brief opens by naming.

⚠️ so the durable artifact is **this brief and its measurement file**, never a check beside
them. a play lives under the gitignored `.play/temporary/`, written to answer one question and
discarded — which is why every m.N states its evidence inline rather than by a pointer at a
file that can rot.

## .the corollary for anyone who writes a check

a check earns its authority when it is **seen to discriminate**: red on a real
break, green on a real pass. a check proven in one direction only is half proven.

`rule.require.seam-claims-have-an-owner` asks for the first half — break the
subject on purpose and watch it go red. this gotcha asks for the second: run it
against a case you know is **good** and watch it go green. a check never seen to
pass is as unproven as one never seen to fail.

## .see also

- `define.cry-wolf-measurements` — every measurement in full, one per question above
- `rule.forbid.failhide` — the false-✔ half of this pair
- `gotcha.pipefail-grep-q` — a false ✔ from an early-exit SIGPIPE
- `gotcha.while-read-drops-the-last-line` — a false ✔, and the print-your-evidence
  habit that caught it
- `rule.require.seam-claims-have-an-owner` — its `.prove the check discriminates`
  section
- `term=bite._.choice._.md` — the word for a check seen to fire on a real break
- `rule.forbid.exemption-as-habit` — m.5's repair retired an exemption claimed correctly and
  not needed; m.9's audit device enforces this rule, and a padded audit defeats it