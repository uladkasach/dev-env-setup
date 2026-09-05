# domain.term.choice.reason: gate

## .etymology
a gate on a path: you reach it, it opens or it does not, and the road past it is walked only
if it opened. that is exactly the shape — a check, and later work that does not run when it
says no.

`gate` was chosen over `guard` for one reason unrelated to the word's fitness: **bhrain's
route vocabulary already owns `guard`**, where it names a stone's validation file
(`N.name.guard`). both repos are read by the same travelers in the same session, so one word
across two contracts is the ambiguity `rule.forbid.domain-term-ambiguity` exists to stop.

`check` was rejected on a sharper boundary — see below. it is the one a reader is most apt
to reach for.

## ⚠️ .why it was itemized LATE, and what that says
this term was used **60 times across 15 briefs** before it was ever itemized. that is a
failure of `rule.require.domain-term-itemization`, and the reason it went unseen is worth
a record:

> a term that is never DISPUTED never announces itself.

every itemized term in this glossary earned its cluster from friction — a synonym argued
(`foamboard`/`foamie`), a word that meant two concepts (`entry`), a verb superseded
(`grove.provision`). `gate` had none. it was used correctly by everyone from the start, so no
round ever stopped over it, and the trigger the obsession waits for never fired.

⇒ so the itemization trigger cannot be *"did this word cause trouble?"* alone. it must also
be *"did this word enter a CONTRACT?"* — which is what finally caught it: on 2026-08-13 the
word entered a **play name**, `prove.prompt-gates-read-both-halves`, and a play name is an
invocable published interface (`--play <name>`), not prose.

## .the boundary that decides `gate` vs `check`/`verify`
this repo already owns `play.verify` and `play.prove`, and both are **artifacts**. `gate` is
not a fourth artifact — it is a **position**:

| | what it is | how it is decided |
|---|---|---|
| `verify` | an artifact — a phase, a play | by its filename |
| `gate` | a position — a check with a skip behind it | by what its CALLER does with the verdict |

so one file can be both, and that is normal: `provision.verify` IS a verify (artifact) and IS
a gate (position, because `bundle_leaf` skips `configure` on its failure). `configure.verify`
is the same artifact in a non-gate position — no phase follows it, so its ✋ is a report.

⚠️ **the practical consequence, and why the boundary earns prose:** a noisy REPORT may be
relaxed. a noisy GATE may not — to relax it produces a silent skip, which is
`rule.forbid.failhide` at the level of a whole phase. so before you soften any check, ask
which position it sits in. that question has been asked informally for months; this term is
what makes it askable in one word.

## .evidence
- **usage census, 2026-08-13** — `grep -c '\bgate\b'` over
  `.agent/repo=.this/role=any/briefs`: 60 hits, 15 files. every hit was read, and all 60 fit
  the single sense in `.choice._.md`. **no overload was present**, which is what settled it
  AGAINST a split into per-scale terms.
- **the four scales**, all in live use: an expression (the tier+tty conjunction), a phase
  (`provision.verify`), a tunnel rung (the ssm gate), a whole skill (`git.grove.provision test`).
- **the contract that forced the itemization** —
  a `prove.prompt-gates-read-both-halves` probe, 2026-08-13.
- **the prior art in this repo's own prose** —
  `rule.require.upgrade-entries-verify-themselves` had already written the definition without
  a term to attach it to: *"a gate, not a report: if this fails, configure is SKIPPED"*.

## .disputes
none raised. the census above is the evidence on record that no synonym is in circulation; if
a later round finds `gate` used for a check that skips no work, that is the dispute to open —
it would mean the term drifted toward `check`, and the boundary above is what to re-argue.
