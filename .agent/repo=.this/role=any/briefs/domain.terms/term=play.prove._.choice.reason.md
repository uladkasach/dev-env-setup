# domain.term.choice.reason: play.prove

## .etymology

**prove** is older than its modern sense of "demonstrate a theorem". its root is latin *probare*,
to TEST by trial — the sense that survives in *proving ground*, in *the proof of the pudding*, and
in *proof spirit*, where a spirit was proven by whether it let gunpowder burn.

that older sense is exactly right here. these plays do not reason about the box; they subject it to
a trial and read what happens. a proving ground is where you drive the vehicle, and the whole point
is that a drive answers what an inspection cannot.

so the word arrives with the right intuition already attached, which is the best case for a term.

## .the argument that produced it

the family already had three verbs, and the playbook readme bound them. the plays this
term names would not sit in any of the three:

- **`diagnose`** asserts no verdict, and these plays exist to assert one
- **`verify`** must not write, and these plays cannot answer their question without a run
- **`repair`** — 📜 a fourth verb at the time, since deleted (2026-08-10). it wrote to CONVERGE
  the box, which is a bundle's job and never a play's (`rule.forbid.repair-plays`). these
  plays drive to OBSERVE, and only ever by a call into `grove.provision` itself

the pressure that forced a fourth word came from `rule.require.prove-each-bundle-plan-apply-apply`,
whose central claim is about a SECOND apply. no read of a converged box can distinguish "this
bundle is idempotent" from "this bundle happens to be done". only a re-run can.

> a property about what a run DOES cannot be settled by a look at what a box IS.

## .the dispute that did not happen, and why it is recorded anyway

the obvious move was to call these `verify.*` and let the family stay at three. that was rejected
before it was written, on the strength of `verify`'s own `.reason`, which states outright that
read-only is not a convention layered onto the word — *it is what the word means*.

to name a play `verify.bundles.plan-apply-apply` would have been a play that applies, twice, under
a word whose definition forbids a write. the `diagnose` / `verify` split rests on that definition,
so the cost would not have been confined to the new plays: it would have loosened `verify`
everywhere, and the next reader would have had no way to tell which `verify.*` plays are safe to
run against a machine they care about.

that is the real hazard, and it is why a fourth word was cheaper than a widened third.

## .the evidence — what the fourth verb buys

each `prove.*` play makes a claim no `verify` could:

| play | the claim | why a read cannot settle it |
|---|---|---|
| `prove.bundles.plan-apply-apply` | each bundle is idempotent | the claim is about a re-run |
| `prove.phase-chain-breaks` | a failed phase stands its siblings down | a phase must first FAIL |
| `prove.rc-ownership` | a neighbor does not break an owner's claim | both must run, in order |
| `prove.tree.fixed-point` | the whole tree settles | the tree must apply itself first |

the last two were born 2026-07-31, out of a defect that proves the family's own blind spot:
`2.5.zsh` and `4.3.1.terminfo` each passed `prove.bundles.plan-apply-apply` — and were broken
together, because that play runs each bundle ALONE. a per-bundle proof cannot see an interaction,
however many times it runs (`rule.forbid.two-writers-on-one-artifact`).

## .the obligation this verb carries

a `prove` play writes to the box, and it asserts a verdict on what it observes. both halves make
it more dangerous than a `verify` when it is wrong:

- a wrong `verify` misreports a state
- a wrong `prove` misreports a state **it just created**, and it mutated a machine to do it

so a `prove` play is held to the discriminate bar of
`gotcha.a-check-that-cries-wolf-gets-silenced`: it must be seen RED on a real break and GREEN on a
real pass, and where only one direction has been observed, the play says so in its own header.

this is not theory. two `prove` plays have already reported a false ✋ against a subject that
worked:

- `prove.phase-chain-breaks` counted the runner's own sign-off as a bundle's claim, and condemned
  a correct fix on a page that showed the fix at work
- `prove.bundles.plan-apply-apply` reported two bundles not-idempotent on evidence that was
  entirely apt's mirror order and pnpm's counter — patterns it already excused, but which an
  indent had hidden from its own `^`-anchored filters

both were defects in the measurement, not in the subject measured, which is the shape a `prove`
play is most apt to carry.

## .disputes

no dispute is open.

## .see also
- `term=play.verify._.choice._.md` — the read-only sibling whose definition forced this word
- `rule.forbid.repair-plays` — why `repair` is no longer a verb here, and the one write-verb
  (`rollback`) that survived it
- `term=play._.choice._.md` — the family, and the verb-leads-the-name rule
- `term=claim._.choice._.md` — what a play asserts
- `rule.require.prove-each-bundle-plan-apply-apply` — the rule that made the verb necessary
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the bar every `prove` play is held to
