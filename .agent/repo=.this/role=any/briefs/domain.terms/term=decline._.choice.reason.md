# domain.term.choice.reason: decline

## .etymology

the word was already in the repo, in three independent places, before it was itemized:

- `term=claim._.choice._.md:14` — a verify *"either proves, or **declines** to prove"*
- `5.10.repos/configure.upsert.sh:38` — *"it DECLINES rather than fails where no key"*
- `src/git-credential-keyrack.sh` — *"declines"* on its own decline path, to git

so this cluster adopts a word the repo declares rather than coins one — the same habit
`exid` followed (`rule.require.conform-to-sdk-environment`, applied inward).

`decline` is right because it is **the speaker's choice, honestly made**. a phase that
declines has looked, has judged the question unaskable, and says so. `skip` would put the
choice in the runner rather than in the phase, and would invite the one reaction a decline
must never invite: *"then run it anyway."*

## .why it earned a cluster on 2026-08-10

`claim` has had a term since the kitty work. its counterpart had none, and the asymmetry
cost real code.

`2.2.git` derives a git identity from the box's github credential. `5.4.gh` wires that
credential — **section 5**, four sections after `2.2.git`. so on every fresh box the
derivation cannot succeed on the first pass, and the phase emitted:

```
✋ git has no identity, and no human is confirmed present to ask
   ⇒ this box's OWN github credential would have answered it, and did not
```

every word of which is true, and the whole of which is *"section 5 comes after section 2."*
the cost was not cosmetic:

- the ✋ was **guaranteed** on the first apply of every new grove
- the phase returned non-zero, so `configure.verify` was skipped entirely
- a reader who trusts the glyph reads a healthy first apply as a failed one

and the repo already had the right answer in four other bundles — `4.5.nvim` for cargo,
`2.5.zsh` for `chsh`, `5.10.repos` for the ssh key, `6.2.codium` for a desktop. four
bundles had independently invented the same move, and the move had no name, so a fifth
author reached for `✋` instead.

> a concept practised in four places and named in none is a concept the next author
> re-derives — or gets wrong.

## 🛑 .and the repair above was WRONG — corrected 2026-08-12

the section above is kept in full because the diagnosis was right and the **cure was not**.

*"the ✋ was guaranteed on the first apply of every new grove"* is the true observation. the
repair applied to it was `✋ → 🌙`, which removed the alarm and left the cause exactly where
it stood: a bundle that cannot converge on a first apply. that is a blocker under
`rule.require.one-command-provision`, and a 🌙 is what let it read as settled for two days.

the real cure is a **MOVE**. on 2026-08-12 the identity left `2.2.git` for `5.15.identity`,
after the `5.4.gh` it derives from, and the tree-sitter build left `4.5.nvim` for
`5.14.treesitter`, after the `5.2.rust` it needs. both now converge on a first apply and
neither emits any verdict but a claim.

⚠️ **a decline was reached for as a REPAIR, and it is not one.** it is a verdict about a
subject. where the subject is fine and the TREE is wrong, a 🌙 does not describe the box — it
describes which directory somebody chose, and it makes that choice comfortable to live with.

⇒ so the four bundles cited above split two ways under the correction: `2.5.zsh` and
`6.2.codium` decline for real reasons; `4.5.nvim` and `5.10.repos` sat in the wrong bundle,
and their 🌙 came out with the phase.

## .why `order fact` did NOT become its own term

the round's first instinct was to itemize `order fact` — *"a fact that is false now and
true later, purely by position in the tree"* — because that is the phrase the code
comments actually use.

it was rejected, for two reasons:

1. **it is a REASON, not a verdict.** what a phase emits is a decline; an order fact was
   held to be one of three reasons to emit one. a term for one reason would leave the other
   two unnamed and the verdict itself unnamed — the least useful of the four possible splits.
2. **`claim` is a verdict, so its counterpart must be one too.** the pair is what makes
   either word load-bear (`rule.prefer.symmetric-term-pairs`). `claim` ↔ `order fact` is
   not a pair; `claim` ↔ `decline` is.

⚠️ **and on 2026-08-12 a third reason to reject it landed, which subsumes both: `order fact`
is not a reason to decline at all.** it is a defect of order, and its cure is a move of the
phase. the concept keeps its name in `term=decline._.choice._.md` — under a RETRACTION, so
the next author who reaches for it meets the argument rather than the pattern.

⇒ it will not earn its own cluster. a term for a defect's excuse would make the excuse
easier to reach for, which is the whole cost this retraction exists to remove.

## ⚠️ .the measurement that keeps a decline honest — 2026-08-10, same day

a decline is the SAFER glyph, and that is exactly what makes it dangerous: it costs the
reader no alarm, so a wrong one is never investigated.

`2.5.zsh` declines when it cannot set the login-shell record:

```
🌙 chsh could not change the login-shell record
   (pam refuses it for a password-less user — every key-only box)
   ⇒ so an interactive bash login hands off to zsh instead
```

both lines are wrong on this box, and the box says so in one command:

```
ground:  …:/usr/bin/zsh     ← sudo chsh SUCCEEDED here
camper:  …:/bin/bash        ← and failed here
```

same box, same pam. the record was written for the seat WITH sudo and refused for the seat
without it, so the cause is **privilege on that seat**, never pam. and the hand-off it
falls back to is guarded by `case $- in *i*` — **interactive only, deliberately** — so it
covers a human at a prompt and covers no duct send, no suite, and no cron, which is the
population that then could not find a single tool on PATH.

⇒ **a decline states a reason, and a reason is a claim about the world.** it may be wrong,
and its glyph will not prompt anyone to check. so the reason a decline gives is owed the
same `rule.require.trust-but-verify` scrutiny as a ✋ — more, because nobody else will give
it any.

## .evidence

- **discovery** — the `2.2.git` order-fact ✋ above, its repair to 🌙 on 2026-08-10, and the
  retraction of that repair on 2026-08-12
- **it is practised here** — bundles decline today for both reasons that hold; the `.refs`
  in the say file name one of each. ⚠️ the original count (6, across "all three reasons")
  was run BEFORE the cluster was written and is not re-cited here, because one of the three
  was withdrawn (`gotcha.my-own-note-became-my-evidence`)
- **the rules it serves** — `rule.forbid.failhide` (a decline must not hide an owed step)
  and `gotcha.a-check-that-cries-wolf-gets-silenced` (a false ✋ decays into a false ✔)

## .see also
- `term=claim._.choice._.md` — the counterpart; a decline is a NON-claim, not a soft claim
- `term=seat._.choice._.md` — the scope behind the second reason that holds
- `rule.require.one-command-provision` — why the retracted third reason is a blocker
- `term=bundle._.choice._.md` — the four phases that emit either verdict
- `gotcha.a-check-that-cries-wolf-gets-silenced` — measurement 3 is a `diagnose` whose rows
  declined on incomplete evidence, which is this term's failure mode
