# domain.term.choice.reason: gap

## .etymology

plain english, and deliberately the most neutral word available. a gap is a space between two
things that are both where they belong — it makes no claim that a part is owed, damaged, or
held. every alternative considered carried a claim the tree does not make:

| word | the claim it smuggles in |
|---|---|
| hole | a piece broke |
| vacancy | a piece is owed |
| reserved | somebody holds it |
| placeholder | a file stands in |
| missing | it should be there |

the tree at `2.4` is in perfect order. only a word with no claim can say so.

## .why contiguity is free to give up

the run order is `sort -V` over the filesystem (`grove.provision._.sh`), and each section's
`_.sh` dispatches its children by name. neither reads a count, neither reads a maximum, and
neither cares whether the integers are dense.

so a gap costs the runtime exactly zero. what it costs a READER is one moment of "where did
`2.4` go?" — and that is answered by a note beside the numbers, which is cheaper than a
rename by every measure.

## .the round that settled it

on 2026-08-02 `2.4.gh` moved to `5.4.gh` (its real dependency is a credential, and the only
source of one is keyrack, which arrives with `5.3.brains`). that left `2.4` open in a section
whose other members had no reason to move.

the tidy-up that tempted was to slide `2.5.zsh → 2.4`, `2.6.starship → 2.5`, and so on. the
count:

- **4 directories** renamed
- **20 shell functions** renamed (`grove_provision_2_5_zsh_configure_upsert` and friends)
- **every** `bundle.upgrade 2.N.x` line in the section dispatcher
- the plan-apply-apply playbook's slug list
- `repo.overview.md`, `rule.require.repo-as-source-of-truth`, and each brief that names
  `2.7.aliases` or `2.5.zsh` as an owner
- every `grove.provision --what 2.5.zsh` a human has in shell history or muscle memory

against a benefit of: the digits read `1 2 3 4 5 6 7` rather than `1 2 3 5 6 7 8`.

**that trade is the defect, not the gap.** a rename that no dependency asked for is churn with
a blast radius, and it breaks the one property the numbers exist to carry — that a number
moves when, and only when, a dependency moves.

## .disputes

### dispute: close the gap — raised 2026-08-02 — status: RESOLVED (leave it open)
- raised.by  = mechanic
- claim      = a section that reads `2.1 2.2 2.3 2.5 2.6 2.7 2.8` looks like a file was lost,
               and a reader will hunt for `2.4`
- counter    = the hunt is answered by ONE comment in the section's `_.sh`, which is where a
               reader already is. the alternative costs 4 dirs, 20 function renames, and every
               downstream reference — to change no fact the tree asserts. and it would set the
               precedent that numbers move for tidiness, which is exactly what put `gh` at
               `2.4` for as long as it was there
- resolution = leave the gap; record the reason beside it. `hole`, `vacancy`, `reserved`,
               `skip`, `missing`, and `placeholder` are forbidden synonyms. dispute closed.

### dispute: gap, for "an unmet precondition" — raised 2026-08-09 — status: RESOLVED (keep `gap` for the tree alone)
- raised.by  = mechanic, against its own prose
- claim      = `diagnose.rootless-docker-viability.play.sh` used "gap" throughout for a `·`
               row — a precondition a box does not yet meet. it reads naturally: the row
               names what the box lacks, and a bundle closes it
- counter    = it is an **overload, and the two senses have opposite polarity**. this
               glossary's `gap` is a fact about the TREE that is CORRECT — the `.what` says
               *"not debt to repay"*, and the whole `.why` argues that to close one is the
               defect. an unmet precondition is the exact reverse: it IS debt, and to close
               it is the entire point. one word, two concepts, and the second states the
               opposite of the first
- resolution = `gap` stays reserved for the bundle-number sense. the play's prose was
               renamed to plain description — **"unmet precondition"** for the state, and
               **"a false `·`"** for the defect where a row reports unmet against a box that
               already meets it.
               ⚠️ no new term was minted. the row's marker (`·` / `✔`) already carries the
               concept, so a noun for it would be a synonym for a glyph every play already
               reads fluently — `rule.prefer.wet-over-dry`, applied to vocabulary. dispute closed.

⚠️ **the tell that caught this one**: the two senses disagree about whether the subject is
DEBT. when a candidate use inverts the polarity of the extant term — correct-as-is vs
owed-and-unpaid — it is never the same concept, however well the sentence reads.

polarity is a cheaper test than definition. a synonym check asks *"do these two mean the
same?"* and invites a yes from any pair that reads alike. a polarity check asks *"would a
repair be right or wrong here?"* and admits exactly one answer.

## .evidence

- **discovery** — the move of `2.4.gh` → `5.4.gh`, and the renumber it invited. the concept
  was named the moment a decision had to be made about the empty number
- **the runtime does not care** — proven on grove-1, 2026-08-02: `prove.bundles.plan-apply-apply`
  reported **42 passed, 2 failed** and `prove.tree.fixed-point` returned
  *"the tree reaches a fixed point ✔"*, with the section list printed as
  `2.1.toolkit · 2.2.git · 2.3.ssh · 2.5.zsh · 2.6.starship · 2.7.aliases · 2.8.tmux`.
  the gap ran clean, on a live box, on the first pass
- **the rule it serves** — `term=bundle`'s *"the number is a DEPENDENCY claim, not a
  preference"*. a gap is that rule read in the negative: a number that no dependency claims
  is a number nobody should move

## .see also
- `term=bundle._.choice._.md` — the number as a dependency claim, and the `2.4.gh` move
- `rule.require.bundle-slug-matches-its-path` — why a rename is never local
