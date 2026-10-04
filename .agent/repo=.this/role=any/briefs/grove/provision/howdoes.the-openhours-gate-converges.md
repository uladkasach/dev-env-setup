# howdoes: the open-hours gate converges, and why each of its choices is forced

## .what

`5.18.openhours` installs a reconciler, a systemd user unit, and a timer that re-asks the
declared policy twice an hour. inside the declared window the GLOBAL commit and radio gates
are closed; outside it they are open.

this brief carries the arguments behind its header, each of which is longer than a bullet.

## it is OPT-IN, and `GROVE_OPENHOURS_ENABLED` is the whole switch

every other bundle converges a FACT about the box. this one enacts a human's declared hours,
which is a **PREFERENCE** — so no run installs a gate the tree has not asked for, and the
flag is the only place that asks.

⇒ the tree currently declares `true`: every box this repo converges carries the gate. set it
`false` and the next apply tears it down.

## .why opt-out TEARS DOWN, where `6.apps` merely skips

`grove_optin`'s *"never uninstalls"* is right for an app: a forgotten `--include` must not be
destructive. it is **wrong for a GATE** — a box opted in once and out later would keep a live
timer that blocks commits, and no line in the repo would declare it.

⇒ so `false` disables the timer and removes what this bundle installed, **and it opens NO
gate.** a human may have closed one by hand, and the safe direction on an unreconciled gate
is closed.

> **opt-out means STOP RECONCILING, never OPEN.**

## .why the flag is a REPO edit and not an `--include` flag

`--include` is per-run, so the gate would need the flag on every apply or be torn down by
the next one — and **a gate a human must re-request forever is a gate they will lose.**

⇒ a declared state converges instead: the tree says what holds, and one command makes the
box match (`rule.require.one-command-provision`).

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

the gate is a fact about the HUMAN's day, not a box's hardware, and the human works through
every box they own. **a grove left open while the laptop closes is the gate with a hole in
it.**

⇒ every box that runs `rhx` gets it, and the verify names the ways a box can fail to.

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
| the SCHEDULE | read by the upsert, the verify, and the payload through a rendered file. a config edited on the box is lost at the next apply (`rule.require.repo-as-source-of-truth`) |
| the reconciler's CWD | derives from `$HOME`, so it is the same sentence on every box. a pointer file would be a second declaration of a fact `$HOME` already carries |
| the schedule CHECK | one reader, so the two halves cannot cut the set two ways (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9) |
| the schedule RENDER | one renderer, so the upsert WRITES and the verify DIFFS one text |
| the role PINS | this dir is installed once and never re-resolved, so a float would make two boxes provisioned a month apart disagree on the skill that moves the gate |
| the cwd STATE | a state, never a boolean, so the upsert and the verify share one fact (m.9) |

⚠️ **the DAYS are a contiguous RANGE, so `mon,tue,thu` is INEXPRESSIBLE.** a set parser is
unbuilt because no one has asked for one. the bound is stated rather than hidden: a split week
needs this to grow a parser first.

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
