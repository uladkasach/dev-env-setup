# rule.require.prove-each-bundle-plan-apply-apply

## .what

every bundle you write or change must be RUN, three times, **against a grove**, before it is
called done:

```sh
# on the grove — reached through its duct (rule.require.reach-a-grove-through-its-duct)
grove.provision --what <slug> --mode plan     # 1. writes no state
grove.provision --what <slug> --mode apply    # 2. does the work
grove.provision --what <slug> --mode apply    # 3. proves idempotency
```

per bundle. not per section, not per session, not once at the end. `--what <slug>` is the unit.

a bundle that has not been through all three **on a grove** is **unproven**, and it may not be
reported as converted.

## ⚠️ .why the target is a GROVE and never the laptop

the box you run against is part of the claim. a laptop cannot prove a bundle, for four
reasons:

- **a converged box proves none of it.** a laptop has years of installs on it, so an apply
  there cannot distinguish "this bundle works" from "this box already had it". the whole
  question a first apply answers — *does the work succeed on a box that does NOT yet hold
  it?* — is unanswerable on a machine that already does.
- **the grove is the box in question.** `rule.require.identical-bundle-composition` says a
  bundle applies everywhere unless it cannot be HELD. the machine whose holding is in doubt
  is the headless one, so it is the one that must be asked.
- **the gates only take their real branch on a grove.** every interactive gate tests
  `!= local@unix`. on a laptop that test is FALSE, so the guarded path — the one written for
  a grove — never executes. a laptop run proves the branch a grove will never take.
- **a laptop is not disposable.** a first apply is the run most likely to be wrong. pointing
  it at the human's working machine risks their environment to learn something a rebuildable
  box could have told you.

### the sudo evidence, 2026-07-30

an apply was attempted on the laptop instead, through a harness with no tty. sudo could not
read a password, so every `apt-get install` failed, and `pkg_install` reported:

```
✋ absent from this box's repos: jq tree unzip ripgrep
   fix: confirm each name, or enable the repo that carries it
```

four packages that have shipped in debian for twenty years, reported absent, with a fix that
sends a human to hunt a repo problem that does not exist. a grove has NOPASSWD sudo, so the
run would have proceeded and the defect would have surfaced where it actually lives. the
wrong target produced a wrong diagnosis of a real bug — and cost a round to unwind.

## .why

a bundle is a CLAIM about a machine. an unrun bundle is a claim nobody checked — and the checks that
feel like enough are not:

- `bash -n` proves the file PARSES. it does not run one line of it.
- a static cross-check that every dispatch line names a declared function proves the NAMES agree.
  it does not prove the dispatch works, that `$GROVE_SRC` is set when a body reads it, or that any
  command in any body succeeds.
- a plan run alone proves the tree DISPATCHES. it deliberately skips every `*.upsert`, so it proves
  no upsert body at all.

each run answers a question the others cannot:

| run | the question it answers |
|-----|-------------------------|
| `--mode plan` | does the tree reach this bundle, and does its verify read the box without a write? |
| `--mode apply` (1st) | does the work actually succeed on a box that does NOT yet hold it? |
| `--mode apply` (2nd) | is it IDEMPOTENT — does a re-run converge rather than fail, duplicate, or prompt? |

## .why the SECOND apply is the one most often skipped, and the most valuable

the first apply runs against an unconverged box. the second runs against a converged one, which is
the state every future run will find. that is where this repo's defects have actually lived:

- `ssh-keygen` re-ran on a box that already had a key, and asked **"Overwrite (y/n)?"** — so a second
  run stalled at a question, and one wrong keystroke destroys the key every remote trusts
- `git clone` into a populated tpm dir fails with "already exists and is not an empty directory"
- `tmux new-session -s _tpm_init` fails with "duplicate session" if a prior run was interrupted
- an unguarded `>>` append stacks a new `exec zsh` line into `.bash_profile` on every run
- `apt-get remove` exits non-zero for an absent package, which is the CONVERGED state

every one of those is invisible to a first apply and obvious on a second.

## .why a PLAN run is not optional either

plan is the only run that is safe to make first, so it is the only one that can catch a defect
**before** the box is touched. it catches:

- a `--what` that names no bundle (which used to run zero bundles and print `🌲 done`, exit 0)
- an undeclared slug — a phase file that did not source
- a dispatch that never reaches the bundle at all

a defect caught in plan costs a re-read. the same defect caught in apply may have already written a
conf, removed a package, or hung a duct.

## .how

run each of the three and READ the output. the pass conditions:

1. **plan** — the bundle appears in the tree output; every `*.upsert` reports `would run (plan)`;
   every `*.verify` runs and reports real facts about the box. exit 0, or an exit whose failures are
   verify claims the box genuinely does not yet satisfy.
2. **apply (1st)** — every phase runs; exit 0. any ✋ is a real defect to fix, not a note to carry.
3. **apply (2nd)** — exit 0 AND the output shows convergence: the upserts report "already …" /
   "no work" where they should, and **no prompt opens, no error is printed, and no state is
   duplicated**.

if the second apply differs from the first in any way other than "already present" messages,
the bundle is not idempotent (`rule.require.idempotent-install-procedures`).

## .the anti-pattern this rule exists to end

📜 on 2026-07-30 a session wrote 36 bundle files across eight bundles, ran `bash -n` on each, ran
a static name cross-check — and executed **zero** of them. it asked for a plan run twice, was
declined twice, and built on anyway.

the lesson is not "verify eventually". a declined or skipped verification is a **blocker**, and
work stops there. 36 files on an unexecuted foundation is 36 files of unknown state, and each one
after the first makes the diagnosis harder.

## .enforcement

- a bundle reported as converted without all three runs = **blocker**
- a second `--mode apply` skipped = **blocker** (it is the idempotency proof, and idempotency is
  required by `rule.require.idempotent-install-procedures`)
- a `--mode plan` skipped because "apply will catch it" = **blocker** (plan is the only run that is
  safe before the box is touched)
- a run whose output was not read = **blocker**; an exit code alone is not the report, since each
  body names its own outcome in its own output
- a change to a bundle that writes a file in `$HOME`, merged without a `prove.tree.fixed-point`
  run = **blocker** — the per-bundle runs above cannot see the one defect that class of change
  causes (see *these three runs are not sufficient*, below)

## .the paved path

do not type 3N commands. `prove.bundles.plan-apply-apply` runs all three per bundle, diffs the
two applies to judge idempotency mechanically, and keeps every run's output on the grove:

```sh
rhx git.grove.push grove-1 --from . --into git/more/dev-env-setup.wip --mode apply
rhx git.grove.send grove-1 --play prove.bundles.plan-apply-apply
rhx git.grove.read grove-1 --lines 40
```

read `howto.prove-bundles-plan-apply-apply.md` first — it covers how to read each verdict, and
in particular which ones need your judgment rather than a rule.

## ⚠️ .these three runs are NECESSARY and they are NOT SUFFICIENT

every run above is `--what <slug>` — **one bundle, alone**. so this rule, and the play that
paves it, are blind by construction to whatever happens when two bundles meet. a bundle can
pass all three perfectly and still be broken by a neighbor.

### the measurement, grove-1 2026-07-31

`2.5.zsh` byte-owns `~/.zshrc` — it `cp`s the checkout over it and its verify demands `cmp -s`
equality. `4.3.1.terminfo` appended its erase block to that same file.

**both passed all three runs.** each converged perfectly in isolation. together they left
`2.5.zsh --mode plan` at `✋ ~/.zshrc DIFFERS from the checkout` permanently — apply it, and
terminfo re-appended on the next pass. and terminfo, the cause, stayed green throughout, so the
red line named the victim (`rule.forbid.two-writers-on-one-artifact`).

no per-bundle run could have caught that, however many times it ran.

### so there is a SECOND gate, at tree scale

```sh
rhx git.grove.send grove-1 --play prove.tree.fixed-point
```

it applies the whole tree twice, plans it, and demands that every bundle which still claims is
one a grove genuinely cannot clear (a credential). that is the human's actual question —
`grove.provision`, then `--mode plan`, is the box done? — and it is the only one that sees
bundles interact.

it names no bundle and no file, so it needs no roster to maintain: any slug that complains
about state the tree itself just left is the defect, whatever produced it.

## .see also

- `rule.forbid.two-writers-on-one-artifact` — the defect the tree-scale gate exists to catch
- `howto.prove-bundles-plan-apply-apply` — the play that does all this, and how to read it
- `rule.require.reach-a-grove-through-its-duct` — the three runs go through the duct, never raw ssh
- `rule.require.idempotent-install-procedures` — the property the second apply proves
- `rule.require.upgrade-entries-verify-themselves` — why a bundle carries its own verify
- `rule.forbid.failhide` — why a silent no-op run is worse than a failure
- `term=play.verify._.choice.reason.md` — the sibling lesson: a `verify.*` play must not mutate, and
  the reason a real apply belongs in a run rather than in a check
