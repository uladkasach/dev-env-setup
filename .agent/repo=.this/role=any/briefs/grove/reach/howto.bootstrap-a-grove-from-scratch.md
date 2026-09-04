# howto: bootstrap a grove from scratch

## .what

take a **brand new** grove — an image with a shell and no devenv — to parity, over the ssm
tunnel. this is the path for a box that has just been built, or rebuilt.

## 🛑 .the bar this whole brief serves — ZERO intervention

> **reach the box. put the repo on it. `grove.provision --mode apply`, ONCE. done.**

that is the entire provision. every step below is either **reach** (wake, trust) or **carry**
(push) or **the one apply** or **the gate**. there is no step that massages a box, answers a
prompt, exports a var, or applies a second time.

| what you type | why it is not an intervention |
|---|---|
| `git.grove.wake` | REACH — a stopped box answers no ssh at all |
| `git.grove.trust.gen` | REACH — trust the endpoint; ssh refuses to speak until it is written |
| `git.grove.push` | CARRY — the code must be on the box before it can run |
| `grove.provision --mode apply` | **the provision.** once per seat, non-interactively |
| `git.grove.provision test` | the GATE — it reads, it converges no state |

🛑 **anything else you find yourself typing is a DEFECT**, and it names the bundle that owes
the work. it is fixed NOW, in `src/grove.provision/`. it is never filed, never noted, never
"flagged for later" — see `rule.forbid.deferred-provision-defects`, which forbids the backlog
entry outright, and `rule.require.one-command-provision`, which is the bar in full.

the ONE legitimate halt is to ask the human to have `ahbode/infrastructure` provision a fresh
grove to test against. every other blocker is fixed in this repo, now.

## .why

the first run on a fresh box differs from every later one, and the differences are where the
time goes. below: the ordered path, plus each trap with its cause.

`howto.provision-a-grove.md` covers the repeat drive of a grove that already has a devenv.
this brief covers the window before that is true.

## .first — confirm the os, then read what it ships

the os is a **declared invariant**: a debian-family unix (ubuntu, pop), and only that. every
package ask routes through `devenv.pkg.sh`, which ASSERTS apt and halts with a named fix on
a box that has none. so the first check is not "which family is this?" — it is "does this image
hold up the declaration?":

```sh
rhx git.grove.wake grove-1 --mode apply
rhx git.grove.send grove-1 --what 'cat /etc/os-release; command -v apt-get'
rhx git.grove.read grove-1
```

no `apt-get` means the image is wrong, not the repo. the cure is upstream — build the box from a
ubuntu ami — because the invariant travels to whoever chooses the image. ⚠️ this repo carries no
rpm path, on purpose: a second answer to every package question costs more than one right image.

⚠️ the **user** is still per-image, and it changes: `ec2-user` on the old box, `camper` on the
new one. that is why every remote path stays home-relative (see the `~` trap).

then read what the image already ships — this decides your transport:

```sh
rhx git.grove.send grove-1 --what 'command -v git curl sudo tmux rsync'
```

| present | consequence |
|---------|-------------|
| `tmux` | the **duct works** — use it, drop `--bare` |
| no `tmux` | the bootstrap window — `--bare --why 'no tmux yet'` until the devenv lands tmux |
| `git` | the clone path is open |
| `rsync` | `grove.push` takes its fast transport (it falls back to tar) |

## .the two ways in — and which to use

### A. push the worktree — for a traveler with the repo

```sh
rhx git.grove.push grove-1 --from . --into 'git/more/dev-env-setup' --mode apply
rhx git.grove.send grove-1 --detach --log '$HOME/grove.provision.log' \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --for cloud --mode apply'
```

this is the right path when you have the repo, and the ONLY path when your changes are not yet
merged — it carries the checkout as it stands, so the grove runs exactly what you have.

⚠️ **`--from .`, never `--from src/`.** a `src/`-only push leaves a grove with no
`package.json`, no `.agent/`, no `readme.md` — so `rhx` cannot run there, no skill is
reachable, and any asset beside a bundle is absent. five briefs each recorded one instance
of that one seam.

`git.grove.push` skips `.git`, `node_modules`, `.log`, `.temp`, and `.agent/.cache` on both
carriers, so `--from .` is the correct and cheap form. it prints the skip list on every run.

### B. the bootstrap — for a bare machine with no push channel

```sh
curl -fsSLo /tmp/devenv.bootstrap.sh https://raw.githubusercontent.com/uladkasach/dev-env-setup/main/devenv.bootstrap.sh
less /tmp/devenv.bootstrap.sh
bash /tmp/devenv.bootstrap.sh --for cloud --mode apply
```

⚠️ this fetches from **main**. it can only run code that is MERGED, so it cannot test an
unmerged change — and pushing the file first destroys the premise, since the whole point is a
machine with no repo and no push channel.

## .the order that works

```sh
# 1. wake it (nat -> box -> ssm gate -> tunnel -> ssh alias)
rhx git.grove.wake grove-1 --mode apply

# 2. trust it once — FIRST contact only, where no prior key exists for this port
rhx git.grove.trust.gen --grove grove-1 --mode apply --trust tofu

# 3. read the box (os + what it ships) — see above

# 4. push the REPO — a REMOTE-HOME-RELATIVE path (see the ~ trap)
rhx git.grove.push grove-1 --from . --into 'git/more/dev-env-setup' --mode apply

# 5. PLAN first — it changes no state and names every step
rhx git.grove.send grove-1 --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --for cloud --mode plan'
rhx git.grove.read grove-1

# 6. apply ONCE, DETACHED — the run outlives the connection
rhx git.grove.send grove-1 --detach --log '$HOME/grove.provision.log' \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --for cloud --mode apply'

# 7. read the roll when it lands
#    ⚠️ `--reply` rides the duct AND returns the command's own output and code.
#       never `--bare` here — that trigger is retired (rule.forbid.exemption-as-habit)
rhx git.grove.send grove-1 --reply --what 'tail -20 $HOME/grove.provision.log'

# 8. the GATE — no command typed between step 6 and this one
rhx git.grove.provision test grove-1
```

⚠️ step 8 is not optional and step 7 is not a substitute for it. a converged box is one that
passes `git.grove.provision test`, and the whole claim of `rule.require.one-command-provision` is that
step 6 runs ONCE, with no command in the gap. any command you find you need there is the
defect, and it names the bundle that owes the work.

## .the traps, each with its cause

### the box sleeps mid-run

a grove is `hibernatable`, and the idle timer does not care that a job runs. a 10+ minute
install can be cut in half — one run died at 547 lines with the log simply frozen.

**fix:** `--detach` so the job owns its session, and `wake` before every step of a long loop.
`wake` is idempotent and REPORTS what it found, so `box [UPDATE] stopped → running` is how you
learn it slept. if reach is lost entirely, cold-boot rather than resume:

```sh
rhx git.grove.stop grove-1 --how halt
rhx git.grove.wake grove-1 --mode apply
```

### an empty result is not a result

on a slept box, ssh HANGS or returns `Connection refused` — and a command that never ran
returns empty stdout, which reads exactly like "found none". this pattern has produced
confident wrong conclusions more than once.

**fix:** treat empty output as UNKNOWN until the exit code says otherwise. `wake` first, then
re-run. never report a finding from a command whose success you did not confirm.

### `--bare` outlives its trigger

`--bare` exists for one window: the duct IS tmux, so a grove without tmux cannot open one. once
the image ships tmux, the trigger stops firing — but the flag is free to type, so it gets typed
from habit, and you silently give up the duct's survive-a-disconnect property on a box that
hibernates.

**fix:** `--bare` now REQUIRES `--why`, which forces you to check the trigger still fires. if
neither `no tmux yet` nor `duct is broken` is true, drop it.

### `~` on `--into` expands LOCALLY

`--into '~/git/...'` reaches the skill already expanded to YOUR home, but the grove's user is
its own (`camper`, `ec2-user`, …). worse, that user CHANGES between images.

**fix:** pass a remote-home-relative path — `'git/more/dev-env-setup'`. ssh and rsync both
treat a relative remote path as home-relative, so it is correct for every user. `git.grove.push`
also REFUSES a `~/` or `/` prefix outright and names the corrected command.

### a first run is not a re-run — the PATH chicken-and-egg

a phase that installs into `~/.local/bin` and then calls the binary by BARE NAME passes on every
re-run and fails on the first. ubuntu's `~/.profile` adds `~/.local/bin` to PATH only if the dir
EXISTED when `.profile` was sourced — and on a fresh box, the phase itself is what creates it.

this is the worst shape a check can have: it works wherever you test it by hand, and fails only
on the machine that matters. `2.6.starship` had exactly this defect.

⚠️ the general form is worse than the bare-name half. the DRIVER inherits its caller's
PATH, and the caller is `ssh <seat> 'bash …grove.provision._.sh'` — which reads no startup
file at all on a bash-record seat. an entire run once held only `/usr/bin:/bin`; every
`provision.verify` called a binary that the `provision.upsert` one line above had just
installed "absent from PATH". what made a second apply look necessary was never
idempotency — it was a DIFFERENT PATH (`gotcha.a-tool-found-by-path-answers-only-a-human`).

**fix:** `grove.provision._.sh` sources `src/zshenv.sh` before it drives any bundle, so the run
carries the same PATH whoever launched it. within a phase, verify by explicit path in any step
that installs to a dir it may have just created.

### a phase that wants a human — a DEFECT, never a trap to work around

a duct IS tmux, so an interactive prompt does not merely fail: it sits on the pane and eats the
next command sent down it. and on a detached run it hangs FOREVER, which reports no outcome at
all — worse than a failure.

so no phase on the provision path may prompt, confirm, or read a tty. `5.4.gh` draws its token
from `@all.camp.GITHUB_TOKEN`; `2.5.zsh` uses `sudo -n`, which cannot prompt by construction.

**fix:** if a phase wants a human, that is the bug. give it a non-interactive source and land it
in the bundle (`rule.forbid.tty-as-a-proxy-for-a-human`). do not hand the human a step.

## .what a good roll looks like

```
🌲 grove.provision finished — every claim held
```

a bundle reports its own outcome and the run CARRIES ON, so one failure never halts the rest.
each ✋ names its own fix, with the `--what <slug> --mode apply` for just that bundle.

🛑 **there are NO expected failures.** a table of "expected" ✋s is the bar's escape hatch in
table form. a box that reaches github through `@all.camp.GITHUB_TOKEN` needs no hand-passed
token, so a ✋ from `5.4.gh` or `5.10.repos` is a defect in that bundle, not a step of the
procedure (`rule.require.one-command-provision`, `rule.forbid.deferred-provision-defects`).

read a ✋ as a bundle that owes work. do not read it as a stage of the bootstrap.

## .prove it is idempotent — a SEPARATE claim, run AFTER the gate

```sh
rhx git.grove.send grove-1 --detach --log '$HOME/grove.provision.2.log' \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --for cloud --mode apply'
```

every bundle must converge, not duplicate — `already installed`, `Nothing to do`, pnpm
`downloaded 0, added 0` (`rule.require.idempotent-install-procedures`).

🛑 **this second run proves idempotency; it may never FINISH the provision.** the two read alike
on screen and are opposite claims:

| the second apply… | means |
|---|---|
| changes no state, clears no claim | ✔ idempotent — the property this section tests |
| clears a ✋ the first apply left | ✋ an ORDERING defect, and the bar is broken |

so run the smoketest BEFORE this, never after. a box that needs run #2 to pass the gate has not
met `rule.require.one-command-provision`, and the fix belongs in whichever bundle ran too early
— never in the human's fingers (`rule.forbid.deferred-provision-defects`).

## .see also

**the bar, and what protects it — read these two before you type a step that is not above:**

- `rule.require.one-command-provision` — ONE command, ONCE per seat, non-interactively,
  deterministically, from scratch, to a box that passes `git.grove.provision test`
- `rule.forbid.deferred-provision-defects` — a defect against that bar is FIXED NOW and never
  filed. the only legitimate halt is "I need a fresh grove"

**the rest:**

- `rule.forbid.repair-plays` — a play may never write; if it would, it is a bundle
- `rule.require.smoketest-before-a-grove-is-declared-ready` — the gate at step 8
- `rule.forbid.tty-as-a-proxy-for-a-human` — why no phase here may prompt
- `gotcha.a-tool-found-by-path-answers-only-a-human` — the PATH seam behind the trap above
- `gotcha.grove-push-into-names-the-destination` — the `--into` shapes
- `howto.provision-a-grove.md` — the repeat drive of a grove that already holds a devenv
- `plan.grove-credentials.md` — how a grove gets a token without a secret at rest
- `rule.require.github-token-at-all-camp` — the one slug every consumer reads
- `readme.md` — the human's copy-paste entrypoint for a bare machine
- `rule.require.idempotent-install-procedures` — why the second run is the real test
- `rule.require.exemptions-name-their-trigger` — why `--bare` must name its `--why`
