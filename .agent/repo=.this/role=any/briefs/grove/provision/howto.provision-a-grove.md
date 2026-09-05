# howto: provision a grove

## .what

drive a fresh grove (a remote box) from bare to tree parity — zsh, starship, tmux,
nvim, node, robot brains — over the ssm tunnel, with no desktop concerns.

## .why

a grove is reached ONLY through an ssm port-forward tunnel, and a *fresh* grove has
neither tmux (so no duct) nor git (so no clone). that order trap is what makes the
first provision run differ from every later one, and it is where the time goes if
you do not know it up front.

## 🛑 .the bar — ZERO intervention

> **`rhx git.grove.provision boot <grove> --mode apply`. that is the provision.**

reach (wake, trust), carry (push), ONE apply per seat, the gate. no other step exists. a box
that needs a prompt answered, a var exported, a play run, or a second apply has NOT been
provisioned — it has been massaged, and the massage is in no inventory.

🛑 whatever you type BESIDE that one command is a **defect in a bundle**, fixed NOW in
`src/grove.provision/` and never filed (`rule.require.one-command-provision`,
`rule.forbid.deferred-provision-defects`). the one legitimate halt is to ask the human to have
`ahbode/infrastructure` provision a fresh grove to test against.

## .the one command

```sh
rhx git.grove.provision boot <grove>                # plan — names each step, drives none
rhx git.grove.provision boot <grove> --mode apply   # the provision
```

it drives four steps, in the one order that works:

| # | step | what it does |
|---|---|---|
| 1 | reach | wake the tunnel, then trust the host key |
| 2 | ground | push, then ONE apply. the seat WITH sudo goes first |
| 3 | camper | push, then ONE apply. the seat that does the work |
| 4 | gate | `git.grove.provision test`, with no command in between |

a **REBUILT** box presents a new host key, so tofu refuses it — correctly. that is an input
about the BOX, never a resume:

```sh
rhx git.grove.provision boot <grove> --mode apply --trust replace
```

### 🛑 do NOT re-expand those four steps into commands here

a skill written back out as prose fails three ways, and
`git.grove.provision.boot.sh`'s own header carries the measurement for each: a skipped step
surfaces three layers down; the order is load-bear and invisible; *"type no command between
step 4 and 5"* is a rule only a human can break.

⚠️ **the internals are the skill's too.** the `--from .` push, the `--detach --log` drive,
the `--reply` verdict read, the absent `--for cloud`, the 97 handler, and the mangled-send
guard are each argued where they live, not here. a copy of any of them in this file would be
one fact with two readers, free to drift with no signal
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

## .what you see while it drives, and what a halt means

the skill prints a line per step and drives each apply detached, so a long stretch of quiet
is normal. two verdict lines end an apply, and they are told apart at a glance:

| the log ends | it means |
|---|---|
| `🌲 grove.provision done` | the apply converged |
| `✋ grove.provision finished with failures` | the apply ran and left work owed |

### 🛑 .exit 97 is NOT a failure — it is NO VERDICT

97 is the transport's own code: *the wire gave out; the command's answer was never seen*
(`gotcha.the-duct-returns-the-send-not-the-answer`, `.the ONE code --reply reserves`).

⚠️ a reader who takes 97 for a failed apply goes on a bundle hunt for a defect that does not
exist, and the run they hunt is still at work behind them — a false ✋ whose fix is plausible
and wrong (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7).

⇒ on 97, **do not re-send.** ask whether the log still grows:

```sh
rhx git.grove.send <grove>.ground --reply --what 'stat -c "born=%w last=%y" $HOME/grove.provision.ground.log'
rhx git.grove.send <grove>.ground --reply --what 'date -u +%H:%M:%S'
```

`last` within a few seconds of the box clock = alive; wait. a re-send would be a SECOND apply,
and the bar counts applies, not attempts (`rule.require.one-command-provision`).

⚠️ the one case where a re-send is NOT a second apply: an unproven DELIVERY. a fresh tmux pane
can eat the first character of a detached line (`setsid` → `etsid`, measured 2026-08-15), so
that run converged no state because it never started. `git.grove.send` now proves its own
delivery via a pid sidecar, and carries that measurement inline — read it there before you act.

### .the landmarks of a healthy apply

what says *alive* rather than *hung* — measured 2026-08-15 on a **fresh** 2-vCPU grove,
ground seat, `born` to `🌲 done` in **9m02s**:

| ~elapsed | what the log shows |
|---|---|
| 0-3m | apt index, `pkg_install` lines, `Setting up …` |
| 3-4m | `Restarting services...`, `No user sessions are running outdated binaries` |
| 4-6m | flatpak — `Installing runtime/org.freedesktop.Platform…` |
| 6-8m | **`Compiling <crate> v…`, hundreds of lines** — the tree-sitter build, and the long pole |
| 8-9m | `Cloning into '…'` — `5.10.repos`, one line per org tree |
| ~9m | `🌲 grove.provision done — access prep · server cloud@aws.ec2 · commit none@none` |

⚠️ **9m is the GROUND seat on a box with a warm apt mirror.** it is a landmark, not a bound —
a thin link or a cold mirror moves it, and the skill's `--within` (45m by default) is the real
cap. treat a run past it as exit 97 above, never as a failure.

⚠️ the rust phase is where a reader mistakes a healthy run for a hang: it emits one similar
line per crate for many minutes. the test is not the CONTENT, it is whether the file still
grows.

## .the traps, each with its cause

⚠️ **two traps that WERE here are now the skill's**, and each is argued where it lives —
a copy in this file would be one fact with two readers (m.9):

| the trap | now owned by |
|---|---|
| a `~` on an `--into` path expands LOCALLY, and the grove's user changes between images | `git.grove.provision.boot.sh`, beside `INTO=` |
| a long job dies with the ssh connection, so it needs its own session and a closed stdin | `git.grove.provision.boot.sh`, at the `--detach --log` drive |

what remains below is not about a command you type — it is about the BOX and the TREE, and
both outlive any wrapper.

### a duct needs tmux, and a fresh grove has none

`git.grove.send` rides ductwork (headless tmux). on a bare box it fails with
`tmux: command not found`, and the duct cannot be opened at all.

**fix:** `--bare` sends over plain ssh with no duct. it exists exactly for this
bootstrap window. once tmux lands, drop `--bare`.

⚠️ this trap is why `howto.bootstrap-a-grove-from-scratch.md` is a SEPARATE brief: first
contact happens before a tree exists, so it cannot reach for the skill above.

### git is absent before the clone that needs it

`5.10.repos` clones the org's trees, and a bare server image ships no git — so the clone would
fail before all else runs.

**fix:** `2.2.git` sits far earlier in the tree than `5.10.repos`, so git is on the box before
any clone asks for it. this is why the tree's ORDER is a declaration and not a convenience:
a bundle's number is its dependency claim (`rule.require.bundles-own-their-dependencies`).

## .the os is a declared invariant, not a discovery

a grove runs a **debian-family unix** (ubuntu, pop) — the same family as the laptop. this is
DECLARED, so no step branches on it. every package ask routes through
`src/grove.pkg.sh`:

- `pkg_assert_apt` — proves apt-get is here, or halts with the named fix
- `pkg_refresh` — refresh the index
- `pkg_install <name...>` — install per-package, and report each miss BY NAME

### what the assert buys

rpm support was removed 2026-07-29: a second family means a second answer to every package
question, and the two answers drift. what the shim cost while it stood:

| the shim's cost | what it looked like |
|-----------------|---------------------|
| a name map | `imagemagick` sat recorded as "absent from the repos" for a whole round while `ImageMagick` was in the base repo — rpm names are case-sensitive |
| an empty translation | a package silently skipped, which reads identically to a package installed (`rule.forbid.failhide`) |
| a per-family url | the ssm-plugin step carried parallel `.deb`/`.rpm` urls, so the branch leaked out of the shim and into the step |
| a genuine gap | `fzf` and `ripgrep` are absent from the rpm repos entirely, so parity was unreachable, not merely inconvenient |

on a debian-family box every one of those four is a non-question: the names are the debian
names, `fzf` and `ripgrep` are in the repos, and the ssm plugin has exactly one url.

⚠️ the assert is what makes the declaration real. an invariant nobody checks is a wish — so a
box with no `apt-get` fails LOUD, and the cure is upstream: build it from a ubuntu ami.

### essential vs optional

`2.1.toolkit` splits the ask on purpose: `jq`/`tree`/`tmux` are essential (a miss fails loud),
while `xclip`/`fzf` are niceties (a miss is named and tolerated). one absent nicety must never
halt parity for every bundle after it.

`xclip` deserves a note: it installs fine on a headless grove (~100kb, inert with no X
display), so its absence is not a package question at all. whether the grove WANTS a clipboard
bridge is a claim about a screen, which belongs in a bundle leaf's
`--applies grove_env_has_screen` predicate, not in a package name map.

## .recovery — if the grove drops mid-provision

hibernate breaks the ssm agent — a resumed agent holds a dead socket and rotated
credentials, so it may never re-register, and a private box is reached ONLY via ssm.

the repair (a resume hook + watchdog) is baked into the grove IMAGE, owned by
`ahbode/infrastructure`. 🛑 this repo declares no provision step for it — image lifecycle is
not this repo's boundary (`rule.require.bounded-contexts`). so a box on an image WITHOUT the
repair has no local fallback. if reach is lost:

```sh
rhx git.grove.stop grove-1 --how halt   # a cold boot, not a resume
rhx git.grove.wake grove-1 --mode apply
```

then relaunch step 4. the run is re-runnable: package installs are idempotent, the clone is
guarded, and the tarball fetches simply re-verify.

⚠️ a relaunch after a DROPPED run is a resume, not a second apply. the bar is about a run that
COMPLETED and left work owed — see the two rules below. a run the box slept through completed
none of itself, so to start it again is the first apply, still.

## .see also

**the bar, and what protects it:**

- `rule.require.one-command-provision` — ONE command, ONCE per seat, non-interactively,
  deterministically, from scratch, to a box that passes `git.grove.provision test`
- `rule.forbid.deferred-provision-defects` — a defect against that bar is FIXED NOW, never
  filed. the only legitimate halt is "I need a fresh grove"

**the rest:**

- `howto.bootstrap-a-grove-from-scratch.md` — the FIRST contact, before a tree exists
- `rule.forbid.repair-plays` — a play may never write; if it would, it is a bundle
- `rule.require.smoketest-before-a-grove-is-declared-ready` — the gate at step 5
- `rule.require.install-via-procedures` — never hand a human a one-off command
- `rule.require.every-function-has-a-driver` — every function must be reached by a phase
- `howto.headless-terminal-streams` — what ductwork is
- `src/grove.pkg.sh` — the package boundary, and where the apt invariant is asserted
