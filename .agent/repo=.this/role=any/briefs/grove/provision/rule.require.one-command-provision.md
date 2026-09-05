# rule.require.one-command-provision

## 🛑 .the rule, in one line

# **ONE COMMAND, RUN ONCE, NON-INTERACTIVELY, PROVISIONS A GROVE FROM SCRATCH.**

```sh
grove.provision --mode apply
```

that is the whole provision. no second apply. no prompt answered. no env var exported by
hand. no play. no massage. a fresh disk goes in, a ready box comes out, and the human types
one thing.

**there are NO exceptions to this rule.** not one. a bundle that cannot meet it is a bundle
with a defect, and the defect is fixed now (`rule.forbid.deferred-provision-defects`).

## .the four properties, and what violates each

every one is load-bear. a run that satisfies three of four has not satisfied the rule.

| property | met when | VIOLATED by |
|---|---|---|
| **one command** | a single invocation converges the box | a second apply that clears claims the first left; a follow-up step; a play; a hand-run fix |
| **non-interactive** | it runs with stdin closed and no human present | a prompt, a confirm, a password, a `sudo` that asks, a `[y/N]` |
| **deterministic** | the same disk yields the same result, every time | an outcome that depends on what ran before it, on who ran it, or on the order two phases happened to land |
| **from scratch** | the subject is a fresh disk | a box that needed a hand-setup, a pre-placed file, or a prior session's leftovers |

⚠️ **a second apply is an interjection.** this is the one most often waved through, because
the box does end up converged and the runtime *is* idempotent. but idempotent means *a re-run
changes no state*, not *a re-run finishes the job*. if run 1 leaves a claim that run 2 clears,
that is an ORDERING defect, and the fix is in the bundle that ran too early — never in the
human's fingers.

## 🛑 .ONE COMMAND PROVES THIS RULE, AND NO PLAY DOES

```sh
rhx git.grove.provision <grove> --mode apply
rhx git.grove.provision test <grove>
```

the gate drives a fresh grove through `grove.provision --mode apply`, a real clone, a real
install, a real testdb, and a real suite. **whatever a run of that command surfaces is the
evidence**, and a `prove.*` play is not evidence at all: a play is a SCRATCH artifact under
the gitignored `.play/temporary/`, written to answer one question and then discarded.

⇒ so where a shape in `define.provision-defect-shapes` cites a play by name, read the play as
**how the shape was FOUND**, never as a check that runs today. the shape is the durable half;
the reader that found it is not.

## .the measurement — 2026-08-12, and it failed on all four

`grove-ahbode-v20260811`, a fresh disk:

| what actually happened | property broken |
|---|---|
| ground apply #1 → 7 claims; apply #2 → 0 | one command, deterministic |
| camper apply → 11 claims, and they did **not** clear on a re-run | one command |
| `ACCESS=test` exported by hand for the testdb | non-interactive |
| the `--into` push aimed by hand, twice | from scratch |

⇒ the box that resulted was good. the PROCEDURE that produced it was four hand steps and
three applies, and none of that is in any inventory.

⚠️ **and every one of those four was filed as a task rather than fixed.** #73, #75, #77, #78.
that is the failure this rule's twin now forbids outright: a blocker was converted into a
backlog entry, so the bar read as an aspiration rather than a gate.

## ✔ .the bar was MET — 2026-08-30, and this is the first time

same grove name, a rebuilt instance, both seats bare. **one command**:

```sh
rhx git.grove.provision grove-ahbode-v20260811 --mode apply --trust replace
```

| property | how it held |
|---|---|
| **one command** | one invocation drove all four steps; ground ~6m, camper ~4m, ONE apply each |
| **non-interactive** | no prompt, no confirm, no env var placed by hand |
| **deterministic** | zero claims on either seat's FIRST apply — no second pass cleared any |
| **from scratch** | a rebuilt instance; the prior disk was terminated 37m earlier |

then `git.grove.provision test`: **its own** rungs 0..4 all held, **31 passed, 0 failed**.

⚠️ **`--trust replace` is an input, never a resume.** it names a fact about the BOX — a
rebuild presents a new host key, so tofu refuses it correctly. `--from` is the flag that
would void the claim, and it was not passed on that run.

### ⚠️ the ONE interjection, and why it does not void the run

the gate halted at **its rung 0, `box`** with *"the grove did not wake"* — because **this
machine's** camp credential had lapsed, which camp does in ~55m. a `keyrack unlock` was typed,
and the gate alone was resumed with `--from 4`.

⇒ that is the exemption this rule already grants, and it earns a worked example: **the unlock
repaired THIS MACHINE's reach and changed no grove state.** the gap forbids a command that
CHANGES THE GROVE, and rung 0 went ✔ on the retry with the box untouched — which is also the
proof that the halt was never about the box.

🛑 **and a local record nearly discarded the whole measurement.** `git.grove.provision` kept a
per-seat note keyed on the grove NAME, and a name survives a rebuild — so the one from-scratch
box this rule waits for read as a second run, on evidence from a disk terminated 79 seconds
before the note it cited. the repair is at cause: put the question to the **BOX**, which holds
the only copy that dies with the disk.

⇒ the rest of the account — the m.4 recursion the halt surfaced, the two ladders a first
repair fused, and the three-valued answer the box-side read had to carry — sits in
`define.provision-defect-shapes`, under `.the run that MET the bar`.

## .why the bar is exactly this and not "eventually converges"

- **a hand step is invisible.** it is in no bundle, so `--mode plan` cannot report it and the
  next box will not get it. that is `rule.require.repo-as-source-of-truth`, broken at the one
  moment it matters most.
- **a hand step is unrepeatable.** the human who did it remembers for a week. the box that
  needs it next month gets a different set of fingers.
- **a prompt is fatal on a duct.** a duct is tmux, so an interactive prompt sits on the pane
  and EATS the next command sent down it. an interactive provision does not merely inconvenience
  a headless box — it wedges it.
- **an ordering defect hides behind a second apply.** the moment two applies become normal, no
  one can tell an idempotent re-run from a job that needed two passes.

## 🛑 .a PLAN CANNOT PROVE THIS RULE — measured 2026-08-12

`--mode plan` short-circuits every `*.upsert` by design and always runs every `*.verify`. so
a clean plan proves one thing only:

> **every VERIFY holds on this box right now.**

it says **not one word** about whether an upsert would succeed. an upsert-only failure is
invisible to it — and that is the failure this rule is about, because an upsert is the half
that has to work non-interactively, once, with no human.

measured on `grove-ahbode-v20260811`, camper seat:

```
# the plan, both seats
$ … --mode plan | grep -cE "✋"
0

# the apply, same seat, same minute
$ … --what 4.3.2.emulator --mode apply
   ✋ sudo needs a password, and no terminal is attached for it to ask on
      · run this from a terminal, so sudo can prompt you
      · on a grove, give the user NOPASSWD for apt-get
```

zero refutations, and a phase that fails on every apply — with a fix-text that names two
hand steps this rule calls blockers. the defect had run on every apply that box ever had.

⇒ **"the plan is clean" is not evidence for this rule.** the only evidence is an APPLY, on a
fresh box, per seat. quote the apply, or quote no evidence at all.

## .the test

> **on a grove built from scratch, does ONE command leave a box that passes the gate?**

```sh
# the whole procedure. if a human types a second line, this rule is broken.
rhx git.grove.provision boot <grove> --mode apply
```

that is the test, and it is the same command the human runs in anger
(`rule.require.prove-the-path-the-human-runs`). `boot` runs the gate as its LAST STEP, with no
command in between — so the gap this rule is about is closed by construction rather than by a
human's discipline.

### .what `boot` does, and why the steps are still written down

the four steps below are what `boot` sequences. they are recorded because **the bar is a
property of the STEPS, never of the wrapper** — a defect lands in one of them, and the fix is
in a bundle:

```sh
# ⚠️ each seat has its OWN $HOME and its OWN checkout, so each is pushed and
#    applied separately — and GROUND GOES FIRST (see `.the two applies are ORDERED`)

# 1-2. ground — the seat with sudo. it converges every box-wide fact
rhx git.grove.push <grove>.ground --from . --into git/more/dev-env-setup --mode apply
rhx git.grove.send <grove>.ground --reply --within 1500 \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --mode apply'

# 3-4. the camper — the seat that does the work. every box-wide fact it needs
#      is one ground just set, so this run asks for no root at all
rhx git.grove.push <grove> --from . --into git/more/dev-env-setup --mode apply
rhx git.grove.send <grove> --reply --within 1500 \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --mode apply'

# 5. the gate, with NO command typed in between
rhx git.grove.provision test <grove>
```

🛑 **do NOT hand these five lines to a human as the procedure.** that is exactly what this
rule forbids, and a rule headed *ONE COMMAND* is the easiest place in the repo to break it —
its own test spells five. `boot` exists so the sequence has one caller, and a howto that
re-spells it invites step 4 to be skipped (`rule.require.install-via-procedures`).

each apply must print `🌲 grove.provision done`. that is the driver's success line — the
failure line reads `✋ grove.provision finished with failures`, so the two are told apart at a
glance and neither needs a claim tally.

exit 0 from the gate, with no command in that gap, is the proof. any command in the gap is the
defect, and it names the bundle that owes the work.

⚠️ **`--reply`, not a bare send.** the default send returns the SEND's exit code, which is 0
whenever the text landed — so a bare send cannot tell a converged apply from a failed one
(`gotcha.the-duct-returns-the-send-not-the-answer`). use `--detach --log` instead only when
the apply must outlive the connection, and then judge it by a second, separate read.

⚠️ **a lapsed credential on YOUR machine is not a command in the gap.** camp credentials
expire in about an hour, so a long session may need `rhx keyrack unlock --owner ehmpath --env
camp` before the gate can reach the box at all. that repairs this machine's reach, not the
grove — the box's state is untouched, and `git.grove.wake` reports `[KEEP]` on every rung when
it was never asleep. what the gap forbids is a command that CHANGES THE GROVE.

## 🛑 .the TEN shapes that break this rule — the catalogue

each costs a second apply, a hand step, or a prompt. **the full account of every shape — its
measurement, its repair, and the clamp that holds it — lives in
`define.provision-defect-shapes`.** what follows is the one question each asks, so a writer can
run the whole set at the keyboard.

| # | the shape | ask, before you write the line |
|---|---|---|
| 1 | a bundle numbered for its SUBJECT, while its real dependency lands LATER | this decline names another bundle — does that bundle run BEFORE or AFTER this one? |
| 2 | a box-wide write asked for by a seat that has no root | before this line asks for root, has it READ whether the state it wants already holds? |
| 3 | a phase DECLARED and never called | does this bundle's `_.sh` hold a `bundle.upgrade` line for every phase file beside it? |
| 4 | a tool installed into a dir the LIVE process cannot see | will a LATER phase of this run need it — and does this phase `export` the dir, or only write an rc? |
| 5 | a decline whose "yet" names a future ONE box class has | name the event that ends the wait: can THIS box class ever produce it? |
| 6 | a skip-guard that tests PRESENCE where the claim is HEALTH | is the artifact written in ONE step or several — and does this bundle declare a VERSION for it? |
| 7 | a VERIFY that reads state a LATER component writes | does this verify read state some OTHER component wrote, and is that component dispatched first? |
| 8 | a test that keys on how the repo ARRIVED, not what it HOLDS | what FACT does this test need, and is `.git` a proxy for it? |
| 9 | a git that can ASK, on a box with nobody to answer | can this call reach `/dev/tty`, on a box with no human? |
| 10 | the DARKEST corner — a path that runs on ONE box class, rarely | which box class runs this line, and how often? |

⚠️ **shapes 3 and 10 have no ambient evidence at all.** a phase nobody dispatches runs on no
box, so no run says so — and a plan reports what RAN. a path that declines on one class and
short-circuits on the other runs on exactly one kind of box, at exactly one moment. neither is
caught by a read of a green page; each needs a reader pointed at the tree or at the wire.

⚠️ and **shape 4's variant has no mechanical repair**: a unix group joins a process at LOGIN,
so no `export` rescues it. re-ask the real question UNDER the grant (`sg <group> -c '<cmd>'`)
rather than assert the grant and hope.

## .what counts as ONE command

the provision is one command **per seat**, because a seat converges its own `$HOME` and no
other (`term=seat`, fact 5). two seats therefore mean two applies — and that is not a
violation, because each is the first and only apply for its own seat.

what IS a violation: a seat that needs its apply run **twice**, or a seat whose apply cannot
complete without work only the other seat can do and which no bundle makes the other seat do.

⇒ a claim of the form *"only ground can do this"* is an interjection **unless a bundle makes
ground do it.** the constrained seat needs what it cannot grant itself, and the grant must
have an owner (`rule.require.seam-claims-have-an-owner`).

### 🛑 the two applies are ORDERED — `ground` first, always

this rule said *"once per seat"* seven times and never said WHICH SEAT FIRST, until
2026-08-13. the order is load-bear, and its absence read as "either order works":

| seat | holds | so it must run |
|---|---|---|
| `ground` | NOPASSWD sudo | **first** — it is the only seat that can install a package, write under `/etc`, or enable a unit |
| the camper | no sudo, by design | **second** — every box-wide fact it needs is one `ground` already set |

⚠️ **camper-first is not merely slower — it produces a wall of ✋ and a half-converged
seat.** the tree's box-wide upserts read `pkg_install <x> || return 1`, so a camper that
cannot install `<x>` aborts that phase — correctly, since the phase did not reach its goal.
the run then reports a claim per bundle, and each names ground as the owner. no hand step is
owed to a human, and the box is still not converged.

⇒ so **"once per seat" is a count, not a permutation.** a provision that works in one seat
order and not the other is still deterministic — the order is part of the procedure, and this
is where it is written down.

⚠️ and it relaxes no clause above. each seat still gets exactly ONE apply, still
non-interactive, still with no hand step. the order names which apply goes first, and is
never a licence for a third.

## 🛑 .every change to the bundle tree is PROVEN ON A GROVE BUILT FROM SCRATCH

a change to `src/grove.provision/**` is unproven until it has run this way — **always**, with
no exception for a small change, a comment, or an obviously-safe edit:

1. **ask the human to have `ahbode/infrastructure` provision a fresh grove.** a box this repo
   already converged cannot test a first apply; it has the state the run is meant to create.
2. push, apply once per seat, non-interactively
3. `rhx git.grove.provision test <grove>` — with no command typed in between

⚠️ a re-used grove proves the SECOND apply and says none of what the first does. that is
exactly the gap that let a four-hand-step provision read as green
(`rule.require.prove-changes-on-a-grove`, sharpened here to *from scratch*).

⇒ **this is the one legitimate reason to halt.** when the tree changes and no fresh grove
exists, stop and ask for one. do not test against a converged box and do not file the proof
for later.

## .enforcement

- a grove that needs any step beyond the one apply per seat = **blocker**, and the defect is
  in the BUNDLES, never in the procedure
- a seat whose apply must run twice = **blocker** (an ordering defect, not idempotency)
- any prompt, confirm, or tty read on the provision path = **blocker**
- an env var, file, or credential placed by hand for the provision to complete = **blocker**
- a bundle whose phase declines with *"only a seat with sudo can do this"*, where no bundle
  makes that seat do it = **blocker**
- a change to `src/grove.provision/**` proven on a RE-USED grove = **blocker**
- a phase file the tree declares that no `_.sh` dispatches = **blocker** — it runs on no
  box, and no run says so; a plan cannot report it, since a plan reports what RAN
- an `*.upsert` half with no `*.verify` half beside it = **blocker** — an upsert reports
  what its last command returned, so its claim has no reader, and a provision half with no
  verify leaves the configure half ungated
- a clean `--mode plan` cited as evidence that this rule holds = **blocker** (a plan runs no
  upsert, so it cannot see the half this rule is about)
- a direct `sudo` in an upsert that asserts privilege BEFORE it reads whether the state it
  wants already holds = **blocker** (it fails on every seat without root, over work that may
  be already done)
- a howto that ends the provision at any point short of a green `git.grove.provision test` = **blocker**
- a gate on the provision path whose ABSENT-fact branch was never exercised — by a fresh
  grove, or else by a direct probe — cited as proven = **blocker** (a converged box
  short-circuits every such gate, so a clean apply is evidence about the skip path alone)
- a call that leaves the box, on the provision path, with no total bound = **blocker**; a
  stall does not fail one phase, it holds the duct, and every command sent afterward queues
  behind it
- a package ask on the provision path that does not first wait out whoever else holds the
  dpkg lock = **blocker**; a fresh ubuntu box boots `unattended-upgrades`, which takes that
  lock for minutes, and `2.1.toolkit` is the first bundle to ask for a package — so the two
  collide on a from-scratch run and never on a converged one. the wait belongs at the single
  apt funnel, ahead of every verb, since `add-apt-repository` accepts no
  `DPkg::Lock::Timeout` of its own
- a **hand-written tool list** inside a reader that judges what reaches off the box =
  **blocker** — it cannot report the member nobody added, and it went stale three times in
  one day (`corepack`, then `cargo` + `fnm`, then the row loop named below)
- a **second declaration of a set the same file already holds** = **blocker**, even where
  both copies agree today. `prove.tool-defaults-are-bounded` declared its subjects in
  `SUBJECTS` and restated them in its row loop; `cargo` and `fnm` were added to the first
  only, so both were staged a listener, probed, watchdogged, and JOINED — the run paid their
  full cost — and neither could reach a row. ⚠️ **the page it printed looked complete**,
  which is what makes this worse than an absent reader: a run that READS a different list
  than it EXECUTES reports a partial measurement in the shape of a whole one
- a bare `wait` in a play or a skill = **blocker**; it joins every background job of the
  shell, so one never-exit child is a hang that wedges the transport
- an upsert skip-guard that tests PRESENCE of an artifact written in more than one step =
  **blocker** — a run cut partway leaves a partial artifact that passes the guard, so the
  upsert skips it on every apply thereafter and the box is unrepairable by any command
- an upsert and its verify that cut ONE set with two readers = **blocker**; they are free
  to disagree, and the input they disagree on is the one the verify exists to catch
- a verify whose fix-text is a HAND STEP against an artifact its own upsert claims to own =
  **blocker** — fix the upsert's reader, never the fix-text
- a verify whose fix-text names a RE-APPLY of its own bundle, for a state that bundle's
  skip-guard counts as done = **blocker**; the re-apply hits the same guard and prints the
  same line forever, so the box is unrepairable by the only command it was given
- a bundle that declares a VERSION or COMMIT pin and guards on presence = **blocker**; the pin
  then governs the first apply and no other, so a bump reaches no box that already holds the
  tool — the deterministic clause, defeated by the bundle's own guard
- a pin declared in a phase file where the bundle's own reader compares against it = **blocker**
  (two declarations of one fact, and an apply that can never converge)
- a `*_state` reader declared in a bundle's `_.sh` and asked by only one of its halves =
  **blocker**; a reader in `_.sh` is declared to be SHARED, so a lone asker means the other
  half cut the set its own way
- a VERIFY that reads state another BUNDLE writes, where that bundle is dispatched later =
  **blocker**; the claim cannot be observed on any first apply, and a converged box hides it
- an ordering note that argues "either order lands" without a read of the bundle's VERIFY half
  = **blocker**; the note is about the upsert, and the verify is what pins the order
- a third-party installer invoked without its rc-modification opt-out, where this repo owns
  the rc it writes = **blocker** (`rule.forbid.two-writers-on-one-artifact`)
- a hand-written list of NEIGHBOURS in a play that guards a shared artifact = **blocker**; the
  neighbor may be a binary this repo merely downloads, so no list and no discovery can be
  complete — run the whole tree and re-ask each owner instead
- a check that reads a checkout and keys on `.git`, a remote, or a branch, where the fact it
  needs is a FILE the checkout holds = **blocker**; the provision pushes rather than clones,
  so the test is false on every grove and true on the laptop that wrote it
- a `git clone|fetch|pull|push|ls-remote`, or a `gh` that shells out to one, on the driven
  path with no `GIT_TERMINAL_PROMPT=0` on the call itself = **blocker**; git opens `/dev/tty`
  and waits forever, and on a duct that eats every command sent afterward
- a `</dev/null`, a pipe, or a `[[ -t 0 ]]` guard cited as what makes a git call
  non-interactive = **blocker**; git never reads stdin for a credential
- a guarantee applied to one call and not to its SIBLING in the same file = **blocker**, and
  the sweep that saw only the first is the second defect
- a 🌙 that appears on a fresh box and clears itself on the second apply, left in place =
  **blocker**; it marks a claim that was never checked where it mattered
- a record of "an apply already ran here" kept LOCALLY and keyed on the grove NAME =
  **blocker**; a name survives a rebuild, so the record outlives its subject and then
  reports a from-scratch box as a second run — ask the box, which holds the only copy that
  dies with the disk
- a probe of a remote box whose answer is TWO-valued = **blocker**; a duct that gives no
  verdict has said none about the box, so "could not tell" is a third arm, and to fold it
  into either of the others buys a false ✔ one way and a false ✋ the other

## .see also

- `define.provision-defect-shapes` — the ten shapes in full: each measurement, each repair
- `rule.forbid.deferred-provision-defects` — the twin: a defect against this rule may never be filed
- `rule.forbid.repair-plays` — where this bar was first stated, as a side-condition
- `rule.require.smoketest-before-a-grove-is-declared-ready` — the gate this path must reach
- `rule.require.prove-changes-on-a-grove` — the general form; this sharpens it to *from scratch*
- `rule.require.seam-claims-have-an-owner` — a grant the constrained seat cannot make itself
- `rule.forbid.tty-as-a-proxy-for-a-human` — why a tty test is not an interactivity test
- `term=seat._.choice._.md` — why one command is per SEAT, and what that does not excuse