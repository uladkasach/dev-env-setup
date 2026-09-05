# domain.term.choice.reason: ladder

## .etymology

a ladder is the one everyday object whose members carry the whole property we needed: a
rung you cannot reach makes every rung above it unreachable too — not merely unclimbed.
that is the exact difference between a `git.grove.ready.verify` and a test suite.

`pipeline` was the near miss, and it fails on the same property: a pipeline's stages are
usually independent enough that a broken stage 2 still lets 3 run on stale input. `chain`
names the order and drops the halt. `sequence` names the order and drops the dependence.

⇒ the word was chosen because the METAPHOR carries the invariant, so a reader who has
never read this file still infers the halt from the noun.

## .disputes

### dispute: the AXIS — raised 2026-08-30 — status: RESOLVED (ladder vs generic)

- raised.by  = the human
- claim      = the members of a ladder are **rungs, whatever they do**. what makes a
               member a rung is its POSITION in a ladder, never its effect.
- counter    = an earlier draft split the two words on READ vs WRITE — `rung` for a
               ladder that asks, `step` for one that acts.
- resolution = **the human's axis stands.** the read/write split does not survive its own
               test: a member's EFFECT is a property of that member alone, where a
               member's DEPENDENCE on the one below it is a property of the whole. only
               the second is what the ladder metaphor carries, so only the second can be
               the axis.

🛑 **this term exists because of that verdict.** the axis names two things — a `ladder`
and a `generic` ordered list — and only one of them had a cluster. a settled axis whose
load-bear noun is undeclared is an axis a later reader can restate any way they like.

### dispute: a WRITE inside a read-only ladder — raised 2026-08-30 — status: RESOLVED (delete)

- raised.by  = the driver
- claim      = `git.grove.ready.verify` carried two members, `6 tree` and `7 suite`, and
               rung 7 ran `git.repo.test --what integration --mode apply` against a live
               testdb — a WRITE, inside a ladder whose header promised read-only.
- counter    = under the settled axis a rung that writes is still a rung, so the write
               alone is no defect.
- resolution = **both were deleted**, and the human named a sharper reason than the
               write: 6-7 were **synonyms** of `git.grove.provision test` rungs 1, 2, and
               4. one fact, two readers, free to disagree
               (`gotcha.a-check-that-cries-wolf-gets-silenced` m.9).

⇒ so the durable lesson is about ANCHORS, not about that ladder. a term anchored in a
shipped artifact inherits that artifact's drift: the anchor is what makes the term
checkable rather than asserted, and it is also what lets a later commit falsify the
definition with no signal at all to the glossary.

## ⚠️ .why the HALT is the design, and not an economy

a ladder that runs every member and tallies at the end prints a wall of red whose rows
are almost all consequences of row one. that is noise a human must then order by cause —
and to order it by cause is exactly the work the ladder was built to have done already.

so the halt is not a saved second of runtime. **the first rung that does not hold is the
only actionable row, and it is the last line printed.** every row a suite would have
added is a row whose cause is above it on the same page.

## .evidence

- three ladders ship in this repo, and they are what the definition is checked against:
  `git.grove.ready.verify` (1-5), `git.grove.provision test` (0-4),
  `git.grove.provision` boot (1-4)
- the ambiguity is measured, not feared: on 2026-08-30 a sentence read *"rungs 0-3"* and
  fused the gate's number set with the verify's, so it told a reader that `tree`, `deps`,
  and `fixture` could fail on their laptop. all three run ON the box.
- the conformance gap is measured too: **2 of the 3 anchors still print `step`** for
  their own members — 12 sites in `git.grove.provision.test.sh`, and `echo "the steps:"`
  plus `--from  first step to run (1-4)` in `git.grove.provision.boot.sh`. the second is
  a **published cli contract**, where `rule.forbid.domain-term-synonyms` grades a
  forbidden synonym a blocker rather than a nitpick.

⚠️ **the repair is not a bare rename, and that is why it is flagged rather than driven.**
today the WORD is what tells the two number sets apart inside
`git.grove.provision.test.sh`: `step N` means this command, `rung N` means the verify it
climbs, consistently, in all 26 sites. rename both to `rung` and that discriminator is
gone — and what remains is two unqualified `rung N` sets in one file, which is the exact
fusion the 2026-08-30 measurement cost an hour to repair.

⇒ the conformance pass must land **with** the qualifier pass, never in front of it: every
citation names its ladder first, and only then may the noun be shared. that is a
3-artifact rename plus ~40 citations — its own ask
(`rule.forbid.inflate-an-additive-ask`).

## .see also

- `term=rung._.choice._.md` — the member; carries the same settled axis from the other side
- `term=gate._.choice._.md` — a gate opens or refuses; a rung also NAMES ITS FIX
- `rule.forbid.domain-term-synonyms` — why the cli-contract row is a blocker
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, the two-readers defect that
  retired rungs 6-7
