# rule.forbid.repair-plays

## 🛑 .the rule, in one line

# **A PLAY MAY NEVER WRITE. IF IT WOULD WRITE, IT IS A BUNDLE.**

no `--mode apply` flag on a play. no `MODE=apply` env var. no repair play, no fix play, no
install play, no setup play, no bootstrap play — **whatever you call it, if it moves a
machine FORWARD toward the declared state, it is a bundle.**

there are **two** exceptions, and neither moves a box forward:

| # | the exception | the write | lifespan |
|---|---|---|---|
| 1 | a `rollback.*` play — un-converge a test box so a bundle's first apply can be re-tested | one way, BACKWARD | **disposable** — it lives in the gitignored `.play/temporary/` |
| 2 | a **discrimination probe** — break a subject on purpose, confirm the check reddens, restore | a ROUND TRIP, net zero | **permanent** — it re-proves the check on every box |

both are below, with their conditions. neither is ever part of the answer to "how do I fix
this box" — that answer is always `grove.provision`.

## 🛑 .the whole procedure to raise a grove — memorize this

```
1. ssh in as the ground seat
2. push the repo
3. grove.provision
```

**that is the entire list.** there is no step 4. there is no "and then run the repair
play". if a grove needs a fourth step, **the fourth step is a defect in step 3** — go
add the bundle.

## 🛑 .the bar this whole rule protects

> **`grove.provision` must run END TO END, IDEMPOTENTLY, and do EVERYTHING.**

`rule.require.one-command-provision` owns that bar and states its four properties. a play
that writes is forbidden because it is a fourth step in disguise, and a fourth step means
the bar is unmet and nobody noticed.

## .the two verbs, and only two

| a play may… | example |
|---|---|
| **READ** the machine and report rows | `diagnose.*` |
| **READ** the machine and assert a verdict | `verify.*`, `prove.*` |

| a play may NEVER… | it belongs… |
|---|---|
| install a package | in a bundle's `provision.upsert` |
| write a config, a key, a manifest | in a bundle's `configure.upsert` |
| create a directory, a unit, a credential | in a bundle |
| "repair" ANYTHING | in a bundle |

## .why — a repair play is a SECOND ENTRYPOINT wearing a costume

`rule.require.grove-provision-as-the-only-entrypoint` says it flatly:

> a second entrypoint that drives devenv state, **whatever it is called** = blocker

a repair play is exactly that. every cost that rule names lands on it:

1. **it is invisible to `--mode plan`.** the plan is the one place a human learns what a
   machine is missing. a repair play holds state the plan cannot see, so the plan LIES —
   it reports a converged box that still needs a hand step nobody will remember.
2. **it is not in the inventory.** the bundle tree IS the inventory
   (`rule.require.bundle-as-sole-declaration`). a repair play is a second, unaudited list.
3. **the next box needs it too, and will not get it.** that is the whole point of this
   repo. a fix that lives in a play fixes ONE machine, ONCE, then is forgotten — it breaks
   `rule.require.repo-as-source-of-truth`.
4. **it converges no state.** it has no verify phase, so it is never re-checked. a play
   run in march is invisible in june.

⚠️ and the failure mode is the nastiest kind: **a grove that a human "fixed" by hand
looks converged and is not.** the next fresh box then fails in a way nobody can explain,
because the fix that made the last one work was never written down where the machine
could read it.

## .measured — a repair play was built, and caught before it landed

🛑 the tell was on screen the whole time: a `MODE=plan` default and a `MODE=apply` branch.
**a plan/apply split is the bundle runtime's job.** the moment one appears inside a play, the
bundle runtime has been re-implemented, badly.

.refs = rule.forbid.repair-plays.demo=repair-play-incidents, m1

## .the eight repair plays this rule cost, and where each concern lives now

each deleted play taught the wrong lesson by example — "a repair play is normal here" — so
each had to go, not merely be discouraged. every concern it carried now lives in a named
bundle, or nowhere, because it cleaned up a mistake rather than converged a state.

.refs = rule.forbid.repair-plays.demo=repair-play-incidents, m2

## ⚠️ .EXCEPTION 1 — a ROLLBACK, to re-test a bundle's first apply

the first of the two circumstances in which a play may write, and it is not a repair:

> **you are DEVELOPING a bundle, and you need to put a box BACK to an unconverged state so
> you can test the bundle's first apply again.**

that is a **rollback**, and its subject is your test box, not production state. it exists so
you can prove the bar above twice on one box — it is never part of the answer.

⚠️ so a rollback that becomes a permanent fixture has inverted its purpose. if you find
yourself running one on a box you did not just experiment on, the bundle does not meet the
bar, and the bundle is what to fix.

### the four conditions — ALL of them

1. **it is named `rollback.*`, never `repair.*`.** the word says what it does: it puts a box
   BACK, so a bundle can be re-tested forward.
2. **it names the bundle it un-does.** `rollback.5.1.node`, not `rollback.the-path-thing`.
   a rollback with no named bundle is a repair play with a new hat.
3. **it never runs on a box that is not a test subject.** it is a development tool. it is
   never in a howto, never in a procedure, never handed to a human as a fix.
4. **it lives in `.play/temporary/`, which is GITIGNORED.** a rollback has the lifespan of
   the experiment that needed it. one that outlives its experiment becomes the fourth verb
   all over again, and the next reader learns the wrong lesson from its mere presence.

```sh
rhx git.grove.send <grove> --play .play/temporary/rollback.5.1.node.play.sh
```

#### condition 4 is enforced structurally, not by memory

**a play that is never committed cannot rot into an exhibit.** `rollback.*` lives in the
gitignored `.play/temporary/`, so the dir enforces the deletion that the old text once only
asked a human to remember.

.refs = rule.forbid.repair-plays.demo=repair-play-incidents, m3

⚠️ note what did NOT change: a rollback still WRITES, so it still needs this exception. the
scratch dir retires the fourth condition's ENFORCEMENT, not the carve-out itself.

### the test that separates rollback from repair

> **does this move the box FORWARD toward the declared state, or BACKWARD away from it?**

- **forward** → 🛑 that is convergence, and convergence is a **bundle**. always.
- **backward, on a box I am experimenting with** → a rollback, bounded by the four above

⚠️ every one of the eight deleted plays moved boxes FORWARD. not one was a rollback. that is
why not one of them survived.

## ⚠️ .EXCEPTION 2 — a DISCRIMINATION PROBE, to prove a check reddens on a real break

the second circumstance, and the one this rule failed to name for a day:

> **you must show that a check goes RED on a genuine break.** no read of a healthy box can
> produce that evidence, so the probe has to MAKE the break, watch the check, and put it back.

### 🛑 why this is not optional

`rule.require.seam-claims-have-an-owner` carries this in its own enforcement:

> a seam check never exercised against a deliberate break = **nitpick**

`gotcha.a-check-that-cries-wolf-gets-silenced` states the general form: a check proven in one
direction only is half proven. one rule **requires** a deliberate break; this rule, as first
written, **forbade** the only artifact that can perform one.

.refs = rule.forbid.repair-plays.demo=repair-play-incidents, m4

### why it passes this rule's own test

the forward/backward test asks which way the box moves. a discrimination probe moves it
**backward and then forward again** — a round trip whose net effect is zero. it never
converges anything, and it leaves the box exactly as it found it.

⚠️ so, unlike a rollback, it is **permanent** — and that is the one place the two exceptions
part company hardest. condition 4 of exception 1 sends a rollback to the gitignored
`.play/temporary/`; a discrimination probe belongs **tracked in the repo**, and
must not be read across: a rollback serves one experiment, where a discrimination probe
re-proves the check on every box, forever. it is a clamp.

🛑 **so a discrimination probe filed under `.play/temporary/` is a BLOCKER, not a tidy-up.**
the dir is gitignored, so the clamp would reach no other box and no other reader — and its
absence would be silent, which is the failure mode a clamp exists to prevent.

### the four conditions — ALL of them

1. **the restore is a `trap … EXIT`, never a last line.** every step between the break and the
   restore can fail — a timeout, a crash, a bad exit — and each would otherwise leave the box
   broken with no note of why. the trap makes the restore unconditional.
2. **it REFUSES to run if the subject is already absent**, rather than invent one and leave
   that invention behind. it may only restore what it actually found.
3. **the break is MINIMAL, and isolates the check under test.** `prove.git-alias-seam` repoints
   `alias.tree` at an undefined function so the alias still EXISTS — which keeps the presence
   check green and leaves the new check as the only thing that can see the defect. a broader
   break proves less, because several checks redden and none is implicated.
4. **it reports whether the restore took.** a probe that breaks a box and goes quiet about the
   repair is worse than no probe (`rule.forbid.failhide`).

### 🛑 the two this exception owes — neither is written yet

| play | what it breaks | what it proves | status |
|---|---|---|---|
| `prove.git-alias-seam` | `alias.tree` → an undefined function | `2.2.git`'s delegate check sees a broken delegate | ✋ **absent** |
| `prove.keyrack-peer-probe-bites` | `pnpm rm -g` the keyrack peer | which of four keyrack calls actually reddens on an absent peer | ✋ **absent** |

both probes are owed, tracked, under this exception's four conditions.
`prove.keyrack-peer-probe-bites` writes destructively — it needs a grove and must not be
aimed at a laptop.

⚠️ **both must be named `prove.*`.** their subject is a CLAIM about a check, which is what
`prove` means here. do not name them `rollback.*`: a rollback's subject is a box, and these
leave the box untouched on net.

.refs = rule.forbid.repair-plays.demo=repair-play-incidents, m5

## .the test — ask ONE question before you write a play

> **does this touch the machine?**

- **yes** → 🛑 STOP. it is a bundle. `src/grove.provision/<n>.<name>/`
- **no, it only looks and reports** → a play is correct

there is no third answer. if you are unsure, it is a bundle.

## .what to do instead, concretely

you found a machine missing something. do this:

```sh
# 1. add the bundle dir — the tree IS the inventory
src/grove.provision/5.devtools/5.12.keyrack/
  _.sh                  # dispatches its own phases
  configure.upsert.sh   # make it so
  configure.verify.sh   # prove it, and re-prove it forever

# 2. dispatch it from the parent's _.sh

# 3. prove it plan → apply → apply on a grove
#    (rule.require.prove-each-bundle-plan-apply-apply)
```

now every box gets it, `--mode plan` names it when it is absent, and the verify catches
it if it ever drifts back.

## .enforcement

- **any play that moves a machine FORWARD toward the declared state = blocker.** delete it,
  write the bundle.
- **a play named `repair.*` = blocker.** the verb does not exist here. the read-only verbs are
  `diagnose`, `verify`, `prove`; the two write shapes are `rollback.*` and the discrimination
  probe, each bounded above.
- **a `rollback.*` that fails any of its four conditions = blocker** — unnamed bundle, run on
  a non-test box, or cited in a howto.
- **a `rollback.*` COMMITTED to the repo = blocker.** it belongs in the gitignored
  `.play/temporary/`. this superseded the old *"kept past the experiment it served"* clause on
  2026-08-30, because that clause named a state no check could see: a rollback and a spent
  rollback are the same bytes, so only its author knew which one the dir held
- **a DISCRIMINATION PROBE filed under `.play/temporary/` = blocker** — the exact inverse. that
  dir is gitignored, so a clamp placed there reaches no other box and no other reader, and its
  absence is silent
- **a discrimination probe that fails any of its four conditions = blocker** — a restore that
  is a last line rather than a `trap … EXIT`, a subject invented rather than found, a break
  wider than the check under test, or a silent restore.
- ⚠️ **a discrimination probe deleted as a "write play" = blocker.** it is exempt, permanently,
  and `rule.require.seam-claims-have-an-owner` requires it. read exception 2 before any cull
  of a play that writes.
- **a `--mode`/`MODE` plan-apply split inside a play = blocker.** that is `bundle.upgrade`,
  re-implemented and unaudited.
- **any change to a transport (`git.grove.send`, a duct, a skill) whose purpose is to let
  a play write = blocker**, and a worse one, because it makes the defect ergonomic.
- **a howto, brief, or comment that instructs a human to run a play to fix a box =
  blocker.** the instruction is `grove.provision`.
- **a grove that needs any step beyond `ssh → push → grove.provision` = blocker**, and the
  defect is in the BUNDLES, never in the procedure.

## .see also

- `rule.forbid.repair-plays.demo=repair-play-incidents` — the dated measurements behind
  every clause above
- `rule.require.grove-provision-as-the-only-entrypoint` — the invariant this enforces
- `rule.require.install-via-procedures` — never hand a human a one-off command
- `rule.require.bundle-as-sole-declaration` — the tree IS the inventory
- `rule.require.repo-as-source-of-truth` — an unrecorded change is the defect
- `rule.require.one-command-provision` — the bar this rule protects, stated in full
- `howto.write-a-grove-play.md` — how to write the READ-ONLY plays that remain legitimate
