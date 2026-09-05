# domain.term.choice.reason: rung

## .etymology

a **ladder** already had a word in this repo's speech — `git.grove.ready.verify` was described
as "a ladder" from its first draft. a ladder's parts are rungs, and the metaphor carries
the one property that matters: **you cannot stand on a rung whose lower rungs are absent.**

that dependency is why the word beats `step`. steps live in a sequence but do not hold each
other up — a build with ten steps can skip step 3 and still run step 4, badly. a rung cannot
be skipped, because the questions above it are literally unaskable:

> "is svc-chat's suite green" is not a false claim on a box with no duct. it is a question
> that cannot yet be asked at all.

## .the halt is the design, not an economy

a first draft ran every rung and tallied. its output on a fresh box was 6 red rows, of which
5 were consequences of row one. a human then had to re-derive the order to know where to
start — which is the very work the ladder existed to do for them.

the halt inverts that: **the last line printed is the only actionable one.** so the ladder's
output length is inversely proportional to how broken the box is, which is the correct
direction for a reader in a hurry.

## .disputes

### dispute: step — raised 2026-08-10 — status: RESOLVED (keep `rung`)
- raised.by  = the round that wrote the ladder
- claim      = `step` is the plain english word, already common in cicd speech, and needs
               no metaphor to explain.
- counter    = `step` carries no dependency. a pipeline of steps may run step N when step
               N-1 failed, and many do — that is what `continue-on-error` is for. this
               structure is the opposite: rung N is **unaskable** without rung N-1, and the
               word must say so or the halt reads as an economy rather than a necessity.
               ⚠️ `step` is also near-taken: `term=bundle` exists as a
               superseded term in this glossary, so a reader meets two senses of one word.
- resolution = keep `rung`; record `step` as a forbidden synonym.

### dispute: step, AGAIN — raised 2026-08-30 — status: RESOLVED (`step` names a DISTINCT concept)
- raised.by  = the round that met the ambiguity in the field
- claim      = the dispute above settled *"should `step` REPLACE `rung`?"* — no. this is a
               different question: **two live skills already spell their own ladders
               `step`**, and neither is the loose, unordered pipeline that dispute rejected.

               | ladder | ordered? | halts? | names its fix? | writes? |
               |---|---|---|---|---|
               | `git.grove.ready.verify` rungs 1-5 | yes | yes | yes | **no** |
               | `git.grove.provision test` steps 0-4 | yes | yes | yes | **yes** — clones, installs deps, brings a testdb up |
               | `git.grove.provision` steps 1-4 | yes | yes | yes | **yes** — pushes, applies |

               so the counter that settled the first dispute — *"a pipeline of steps may run
               step N when step N-1 failed"* — is simply not true of these two. they halt.
- counter    = then rename them to rungs. **refused, by this term's OWN definition:** it
               forbids `stage` because that word *"implies a pipeline that RUNS work; a rung
               only asks a question"*, and `git.grove.ready.verify`'s header states the same as a
               safety property — *"this WRITES no state of its own."*

               ⇒ read-only is DEFINITIONAL to `rung`. a ladder that clones a repo and runs a
               suite cannot take a word whose contract is that it asks and does not act. to
               rename them would erase the one property that separates `rung` from `stage`,
               which this cluster already argued once.
- resolution = 🛑 **SUPERSEDED the same day — see the dispute below.** it read: *"both words
               stand, for different concepts. `rung` = an ordered member of a READ-ONLY
               ladder that halts. `step` = an ordered member of a ladder that DOES WORK and
               halts."* the human overruled the AXIS, not the split.

               ⚠️ the earlier counter also called `step` *"near-taken"* by
               `term=bundle`. that term was superseded on 2026-07-30 and is
               marked so, so it reserves the word for no live concept.

### dispute: the AXIS — raised 2026-08-30 — status: RESOLVED (ladder vs generic)
- raised.by  = the human, who read the read-vs-write split above
- claim      = the split is real, and its AXIS is wrong. a ladder's members are **rungs**,
               whatever they do. `step` is the **generic** word for one ordered move, and it
               stays legal everywhere a ladder is not in play.
- counter    = but then a ladder that WRITES takes a word whose contract was that it only
               asks — the very property the `stage` rejection rests on.
- resolution = **the human's axis stands, and the `stage` rejection survives it.** `stage` is
               refused for a different reason than read-only: it names a pipeline whose
               members run independently, and a ladder's do not. that reason is about
               DEPENDENCE, which is exactly what the new axis keeps.

               ⇒ so read-only was never load-bear; it was a coincidence of the first ladder
               this word was coined for. `git.grove.ready.verify` happened to be read-only,
               and a property of the first instance was mistaken for a property of the class.

               ⚠️ **the test that settles it:** a member's EFFECT is a property of that
               member. a member's DEPENDENCE on the one below it is a property of the WHOLE.
               only the second is what the ladder metaphor carries, so only the second can be
               the axis. a definition keyed on the first would have split one concept in two
               and left every caller to pick a word by what its last line happened to do.

#### ⚠️ .the cost of the ambiguity, measured 2026-08-30

this dispute is not tidiness. the two ladders were conflated **inside a repair for a defect
about exactly this kind of conflation**, one hour after that defect was recorded:

```
⚠️ note WHICH rung: 0-3 can halt on THIS machine with the box
   healthy; 4 and up are the box.
```

`0-3` are smoketest STEPS; the *"this machine"* property belongs to ready.verify RUNGS 1-3.
smoketest steps 1-3 are `tree`, `deps`, `fixture` — **all of which run ON the box.** so the
line told a reader to excuse a real box failure as a laptop problem, which is
`gotcha.a-check-that-cries-wolf-gets-silenced` m.4 aimed the other way.

⇒ **one word over two ordered ladders that both halt produced a wrong repair for a
wrong-subject defect.** that is the sharpest argument the split could have, and it is why
this is recorded rather than left as a preference.

#### 📜 .the census that TRIGGERED both disputes — 2026-08-30

a census of `git.grove.ready.verify` found the ladder held **seven** rungs, not the five the
say-level table cited, and that the seventh ran:

```sh
git.repo.test --what integration --mode apply --thorough
```

against a live testdb — the identical command `git.grove.provision test` step 4 issues.

under the read-vs-write axis that was a contradiction: a WRITE at a rung's number, inside a
ladder whose header promised read-only. **under the axis that replaced it, it is not one** —
a rung may write. so the census did not settle the axis; it exposed that the axis was drawn
on the wrong property, which is the dispute above.

⇒ **the rungs were deleted anyway, for a reason that survives both axes.** the human named
it: 6-7 re-asked three questions `git.grove.provision test` steps 1, 2, and 4 already ask.
they were **synonyms** — one set with two readers, free to drift with no signal
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9). the `--repo` flag that fed them went
with them, and the ladder's subject is now the BOX, end to end.

⚠️ **a term anchored in a shipped artifact inherits that artifact's drift.** the anchor is
what makes the term checkable rather than asserted (`.evidence`, below) — and it is also
what lets a later commit falsify the definition with no signal to the glossary. so an anchor
owes a periodic re-read, never merely a citation.

⚠️ and the sharper half: **the anchor did not falsify the definition — it falsified the
axis.** the term was fine; the line drawn between it and its neighbour was not. when an
anchor contradicts a term, ask which of the two is wrong before you move either.

### dispute: gate — raised 2026-08-10 — status: RESOLVED (keep `rung`)
- raised.by  = the same round
- claim      = each rung refuses passage when it does not hold, which is what a gate does.
- counter    = a gate's whole contract is open-or-refuse. a rung owes a third duty: **it
               names its fix** (`rule.require.errors-name-the-fix`), so `halt 3 duct 'tmux
               is absent — run 2.8.tmux'` is a rung and not a gate. a gate that named fixes
               would be an odd gate; a rung that did not would be a broken rung.
               additionally `gate` reads as a thing you pass THROUGH, which loses the
               vertical dependency the ladder metaphor exists to carry.
- resolution = keep `rung`; record `gate` as a forbidden synonym.

## .evidence

the term is anchored in a shipped skill, not in prose alone
(`gotcha.my-own-note-became-my-evidence`):

- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh` declares a `halt` operation
  that accepts a rung number, a rung name, and a fix; every call site is a rung. the exit
  code `3` means "a rung did not hold", distinct from `2` (bad input) and `1` (malfunction).
- the dependency claim is checkable rather than asserted: rung 4 reads a checkout the duct
  from rung 3 must carry, and rung 5 reads a rack the converged tree from rung 4 installs.

  📜 that second clause once cited rungs 6-7, and credited rung 6 with a clone it did not
  perform — it read `test -d …/.git` and halted with a `git clone` fix. the sentence gave a
  READ rung the WRITE its fix-text merely names, which is the same conflation this whole
  cluster exists to hold apart. both rungs were deleted 2026-08-30.

## .refs
- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh`
- `.agent/repo=.this/role=any/briefs/grove/reach/howto.grove-ready-test.md`
- `.agent/repo=.this/role=any/briefs/grove/reach/gotcha.the-duct-returns-the-send-not-the-answer.md`
