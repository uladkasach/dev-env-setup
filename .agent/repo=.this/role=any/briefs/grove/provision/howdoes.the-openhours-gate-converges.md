# howdoes: the open-hours gate converges, and why each of its choices is forced

## .what

`5.18.openhours` installs a reconciler, a systemd user unit, and a timer that re-asks the
declared policy twice an hour. inside the declared window the GLOBAL commit and radio gates
are closed; outside it they are open.

this brief carries the arguments behind its header, each of which is longer than a bullet.

## it is OPT-IN, PER BOX — the marker at `GROVE_OPENHOURS_OPTIN` is the whole switch

every other bundle converges a FACT about the box. this one enacts a human's declared hours,
which is a **PREFERENCE** — and a preference is held by a SEAT, not by a tree. one human runs a
laptop they want fenced and a grove they do not, so a tree-wide boolean cannot express it.

⇒ the DEFAULT is off. a box carries the gate only where the marker is placed.

## .why this is NOT a per-machine bundle subset

`rule.require.identical-bundle-composition` forbids a per-machine subset, and it is not bent
here: EVERY box runs this bundle and every one of its phases. what varies is what it CONVERGES
TO — installed where the marker is present, torn down where it is absent. `1.2.power` has the
same shape: it converges logind to a declared value.

⇒ the rule governs which bundles RUN. a flag the BODY reads is not a decline
(`rule.require.optin-bundles-converge-to-their-flag`).

## .why opt-out TEARS DOWN, where `6.apps` merely skips

`grove_optin`'s *"never uninstalls"* is right for an app: a forgotten `--include` must not be
destructive. it is **wrong for a GATE** — a box opted in once and out later would keep a live
timer that blocks commits, and no line anywhere would declare it.

⇒ so an absent marker disables the timer and removes what this bundle installed, **and it opens
NO gate.** a human may have closed one by hand, and the safe direction on an unreconciled gate
is closed.

> **opt-out means STOP RECONCILING, never OPEN.**

## .why a BOX-SIDE marker, where the schedule stays in the TREE

the two facts have different owners, and `rule.require.repo-as-source-of-truth` is satisfied
by both. the SHAPE of the gate — its hours, zone, units, pins — is one fact for every box, so
the tree holds it and a fresh box inherits it. the ELECTION — does THIS seat want a fence —
differs per box, so no tree value can carry it.

⇒ the rule's two stated harms both miss: no value is "lost at the next apply", because the
bundle READS the marker and never writes or removes it. and "the next machine never gets it" is
the POINT, since opt-in-only means a fresh box correctly carries no gate.

## .why the marker is a box-side file and not an `--include` flag

`--include` is per-run, so the gate would need the flag on every apply or be torn down by the
next one — and **a gate a human must re-request forever is a gate they will lose.** a placed
marker converges instead: the box says what it wants, and one command makes it match
(`rule.require.one-command-provision`).

## .the marker's contract

- it lives under `~/.config`, never `~/.local/state`. xdg splits them by OWNER: config is what a
  HUMAN writes, state is what a program writes. the teardown removes files from the state dir,
  so a marker kept there would be deleted by the very opt-out it must survive
- PRESENCE is the contract, and the content is never parsed. a parsed value needs a grammar, and
  `OPTIN=ture` reads as neither true nor false, so the bundle would have to guess or fail.
  presence has no grammar to get wrong, so the body is free text for the human's reason
- the bundle READS it and never writes it. a bundle that created it on apply would grant the
  opt-in it was sent to ask about, and the default would be off in name alone

## .why this bundle OWNS a linked dir, rather than reach for a checkout

`rhx` finds a skill by a pure filesystem read of `$cwd/.agent/repo=*/role=*/skills/*`
(`discoverSkillExecutables.ts:26`), and the gate skills also call `require_git_repo`. so the
reconciler's cwd owes **TWO** facts: a repo, and a role link.

no checkout on a grove holds both, and that is **DECLARED rather than drifted**:
`5.10.repos.configure.upsert:138` states this repo's src *"arrived by 'grove.push', not by
clone — expected on a grove"*. rsync skips `.git` and `node_modules`, so the pushed tree is
not a repo and its role symlinks dangle.

- 📜 measured on grove-ahbode-v20260901: **110 `repo=.this` skills found, both gate skills
  absent**

⇒ so the cwd is a dir this bundle BUILDS: `git init`, the two role packages installed,
`rhachet roles link` run. one mechanism, identical on a laptop and a grove
(`rule.forbid.divergence-without-a-physical-reason`).

## .why 5.devtools and not 1.system

it drives `rhx git.commit.uses` and `rhx radio.uses`, so it needs `rhx` (`5.3.brains`) and
node (`5.1.node`). a bundle numbered for its SUBJECT while its dependency lands later is
defect shape 1 of `define.provision-defect-shapes` — this is numbered for where its
dependency already is.

## .why it declines nowhere

a decline is a claim that a box CANNOT hold the subject, and every box that runs `rhx` can hold
this one. so the bundle and all four of its phases run everywhere, and the verify names the ways
a box can fail to carry what its own marker asked for.

⚠️ **the HOLE moved to the marker, and it is the human's to close.** the gate is a fact about the
human's day, and the human works through every box they own — so a grove left open while the
laptop closes still takes commits. a tree-wide flag closed that hole by force and cost the human
the choice. a per-box marker hands back the choice and the hole with it, so opt-in is a PER-BOX
act (`howto.opt-into-openhours`).

## the zone is read off `/usr/share/zoneinfo`, NEVER via `date`

- 📜 measured 2026-09-17: `TZ="Nonsense/Zone" date +%H%M` **exits 0 and answers in UTC**
- so a typo'd zone yields a silently WRONG window, and an exit-code check would read it as
  valid — **a gate that closes at the wrong hour, with no signal**
- ⇒ the check asks whether the zone names a FILE

⚠️ and `10#` rides on the times: bash reads `0800` as OCTAL, and `8` is no octal digit.

## the pin is guarded on the installed VERSION, never on presence

a pin guarded on presence governs the first apply and no other, so a bump reaches no box that
already holds the tool — the deterministic clause of `rule.require.one-command-provision`,
defeated by the bundle's own guard (`define.provision-defect-shapes`, shape 6).

⇒ drift off the pin reads `half`, and the upsert rebuilds.

## the declarations that have ONE holder, and why

| the fact | why one holder |
|---|---|
| the opt-in READER | one reader, so the upsert and the verify cannot cut the set two ways (m.9) |
| the SCHEDULE | read by the upsert, the verify, and the payload through a rendered file. a config edited on the box is lost at the next apply (`rule.require.repo-as-source-of-truth`). the marker is the opposite case on both counts: no apply writes it, and a fresh box with no gate is what opt-in MEANS |
| the reconciler's CWD | derives from `$HOME`, so it is the same sentence on every box. a pointer file would be a second declaration of a fact `$HOME` already carries |
| the schedule CHECK | one reader, so the two halves cannot cut the set two ways (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9) |
| the schedule RENDER | one renderer, so the upsert WRITES and the verify DIFFS one text |
| the role PINS | this dir is installed once and never re-resolved, so a float would make two boxes provisioned a month apart disagree on the skill that moves the gate |
| the cwd STATE | a state, never a boolean, so the upsert and the verify share one fact (m.9) |

⚠️ **the DAYS are a contiguous RANGE, so `mon,tue,thu` is INEXPRESSIBLE.** a set parser is
unbuilt because no one has asked for one. the bound is stated rather than hidden: a split week
needs this to grow a parser first.

## how the upsert installs the gate, and why each step is shaped so

- a USER timer, never a system one: the gate state lives under the human's `~/.rhachet/storage`,
  and a system unit fires as root, whose `$HOME` is `/root` — it would run correctly and gate the
  wrong account
- `daemon-reload` before `enable --now`: systemd caches unit files, so a rewrite alone leaves the
  OLD one live, and the fix lands on disk while the box keeps its prior behavior
- the files are COPIED from `$GROVE_SRC/machine/`, never heredoc'd in the phase. a heredoc makes
  the phase the only place the text exists, so a verify could assert presence and never CURRENCY
- LINGER is attempted and never asserted: a headless box needs it, a laptop with a live session
  does not. the upsert attempts the grant and reports, and the verify reads it back
- the schedule is graded BEFORE the marker is read, so a typo is caught the day it is written —
  never the day somebody opts in and wonders why the gate shuts at the wrong hour
- the opt-out hint names the SKILL (`machine.openhours.optin.set`), never a hand-rolled `mkdir`
  plus redirect. the bundle must not write the marker, so a human places it
  - 📜 the hint spelled the two raw commands until 2026-10-01. a redirect one character off
    writes a marker the bundle never reads, so the next apply tears the gate down and reports
    success
- the cwd guard is the shared three-valued reader, never `[[ -d ]]`. a build cut partway leaves a
  dir that passes a presence test and reaches no skill, so a presence guard would skip it forever
  (`define.provision-defect-shapes`, shape 6)
- the schedule file is RENDERED, never hand-placed. the payload runs from `~/.local/bin`, outside
  any checkout, so it cannot source the declaration. the verify diffs a fresh render against it
- the upsert converges the gate once, at once. an apply that installs a gate un-converged reports
  success over a box whose gate is whatever it was — on a first apply, "open", inside open hours

## how the verify proves the gate, and the one claim it cannot make

- the timer needs BOTH `is-enabled` and `is-active`: is-active asks about THIS boot, is-enabled
  about the NEXT. a `start` with no `enable` is active and disabled — green today, gone tomorrow
- the opt-out claim INVERTS with the flag: an opted-out box with a live timer is the defect,
  since a schedule no declaration holds still blocks commits
- the mode bit is its own row: systemd runs the payload via ExecStart, so an unexecutable file
  fails every tick with 203/EXEC — loud in the journal, silent to anyone who reads the gate
- the schedule is DIFFED, never tested for presence: the payload reads that file alone, so a
  stale copy enforces yesterday's window while every other row stays green

### 🛑 SKILL REACH is its own claim, and the one that BIT

`rhx` finds a skill among the roles LINKED into its cwd — `.agent/` plus installed
`rhachet-roles-*` (`isRepoLinked.ts`). a bare `git init` dir satisfies both skills'
`require_git_repo` and can never satisfy that link:

```
✋ ConstraintError: no skill "git.commit.uses" found in any linked role
```

every other row was ✔ against exactly that box. the cwd state reader reads the SHAPE of a dir
and proves no part of reach — only an ask does, and it asks as the reconciler asks: from that
cwd, with a `get`, which mutates no gate and trips no tty guard. on a failure it quotes the
probe's own SENTENCE, never the frames: a bun throw prints a stack AND a numbered
source-context block, and both bury the line that names why.

### reported, never failed

- LINGER: a headless box needs it, a laptop with a live session does not. one claim cannot be
  true of both, so the row reports the state. the upsert attempts the grant
- the gate RIGHT NOW: the correct value depends on the clock, so an assert would be a second copy
  of the policy, free to drift. the payload owns the policy; the row merely says what a human
  would otherwise `cat`

### 🛑 the CONVERGE leg is unproven on a box with no drift

every row is a READ, and the reconciler's job is a WRITE that happens only on DRIFT — so on a
converged box the mutate leg has never run. to manufacture drift, the verify would have to OPEN a
gate a human closed, the one direction where a failure leaves the box UNSAFE. so the honest proof
is the next real boundary pass, and the verify names the journal line that reads it
(`rule.forbid.failhide`).

## .see also

- `5.18.openhours/_.sh` — the header this brief backs
- `howto.opt-into-openhours.md` — the human's procedure
- `define.provision-defect-shapes` — shapes 1 and 6, both named above
- `rule.require.one-command-provision` — the bar every argument here serves
