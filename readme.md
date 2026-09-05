# dev-env-setup

my development environment, as code — shell, editor, terminal, toolchain — for a
**debian-family** linux (ubuntu, pop), on a laptop or a headless cloud box.

## .start here — a bare machine

you have only a terminal. fetch the bootstrap, **read it**, then run it:

```sh
curl -fsSLo /tmp/grove.bootstrap.sh https://raw.githubusercontent.com/uladkasach/dev-env-setup/main/grove.bootstrap.sh
less /tmp/grove.bootstrap.sh
bash /tmp/grove.bootstrap.sh --for local --mode apply
```

three lines, and the middle one matters. **never pipe a remote file into a shell** — read what
you are about to run first. that is why this is not a `curl | bash` one-liner.

`grove.bootstrap.sh` installs git, clones this repo over **https** (anonymous — no credential, no ssh
key), then hands off to the installer. it is idempotent, so a re-run is safe.

### a machine that already has the repo

skip the bootstrap and reach the entrypoint through its skill:

```sh
rhx grove.provision --from main --for local --mode apply
```

🛑 **never `bash …/grove.provision._.sh`.** the driver is reached through `rhx`, always —
`rule.forbid.the-driver-by-path` carries the ban and the two carve-outs.

## .the two commands

| command | what it is |
|---|---|
| `grove.bootstrap.sh` | gets the repo onto a bare machine, then hands off. run once, standalone |
| `rhx grove.provision` | **the** entrypoint's one invocation surface. every bundle runs from here |

`grove.bootstrap.sh` reads none of the upgrader's flags — it forwards them — so the two can never
disagree about what `--for` or `--mode` mean.

> there was a second entrypoint, `src/install_env._.sh`, until 2026-07-30. it is **gone**. two
> entrypoints over one tree meant a guard added to one was a guard in neither, because no reader
> could tell which one a given run took — see `rule.require.grove-provision-as-the-only-entrypoint`.

## .the flags

```sh
rhx grove.provision [--from tree|main] [--for local|cloud] [--mode plan|apply] [--what <slug> ...]
```

| flag | what it does |
|---|---|
| `--for local` | a machine with a screen and a human's identity — the full set |
| `--for cloud` | a headless box — each bundle declines for itself where it cannot apply |
| `--mode plan` | lists every bundle a run would touch, and still runs the verifies |
| `--mode apply` | runs it |
| `--what <slug>` | runs just the named bundles, repeatable. a slug names its whole subtree |

`--for` is detected when omitted (a display, a seat, or a compositor means `local`).

**always plan first:**

```sh
rhx grove.provision --for cloud --mode plan
```

## .how a bundle is chosen

a grove's state is a **tree of bundles**, and that tree is the directory tree under
`src/grove.provision/`. the root reads the top-level directories in numeric order — so the
filesystem IS the inventory, and there is no hand-kept list to drift from it
(`rule.require.bundle-as-sole-declaration`).

```
src/grove.provision/
  1.system/       the box — keybinds, power, browser, kernel, swap, procs, /tmp
  2.shell/        git, ssh, gh, zsh, starship, aliases, tmux
  3.cosmic/       the desktop — terminal, theme, settings
  4.terminal/     fonts, ptyxis, kitty, vim, nvim
  5.devtools/     node, rust, brains, ripgrep, psql, aws, terraform, docker, ...
  6.apps/         flatpaks, codium, dropbox, protonvpn
```

there is **one** operation, the same at every depth: `bundle.upgrade <slug>`. a bundle's body
either dispatches its children or does the work.

**where a bundle applies is the bundle's own business.** a parent never gates a child — kitty's
terminfo entry is useful on a headless box and kitty itself is not, and only those two bundles
know that. so a leaf that cannot apply DECLINES, in its own body, with its reason beside it:

```sh
if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
  echo "   🌙 declined — the monitor alerts through notify-send, and"
  echo "      $GROVE_ENV_SERVER has no notification bus to alert onto."
  return 0
fi
```

a bundle reports its own outcome and the run carries on to the next bundle, so one failure never
halts the whole tree — each `✋` names its own fix, where it happened.

**within** one bundle, though, the four phases are a chain, not a set: `provision.upsert` makes
the subject exist, `provision.verify` proves it, `configure.upsert` shapes it, `configure.verify`
proves that. each presumes the one before. so when a phase fails under `--mode apply`, the rest
of THAT bundle stand down:

```
├─ 5.4.gh.configure.upsert
✋ gh is unauthed, and no human is confirmed present to answer a login
   fix: export GH_TOKEN=<a token that may read the orgs>
├─ 5.4.gh.configure.verify — skipped; an earlier phase of 5.4.gh failed
```

before that, all four ran and printed the same complaint with the same fix line four times —
one cause under four hats, and the noise buried the one line you must act on. the skipped
phases are still NAMED, never silently dropped, so the run still accounts for every phase it
owed.

`--mode plan` never breaks the chain: a plan is a SURVEY, and to stop early there would hide the
rest of the work you asked to see.

## .layout

```
grove.bootstrap.sh              the bare-machine start point
src/
  grove.provision._.sh            THE entrypoint — the root of the bundle tree
  grove.provision/                the tree. the directories ARE the inventory
  bundle.upgrade.sh              the runtime — one verb, at every depth
  grove.env.sh                  the machine, derived once (access/server/commit)
  grove.pkg.sh                  the package boundary — asserts the apt invariant
  machine/                       tracked commands + systemd units the bundles install
  bash_aliases.sh                aliases + functions → ~/.bash_aliases
  zshrc.sh                       zsh + starship + fzf → ~/.zshrc
  init.lua                       neovim config
codium/                          vscodium settings sync
guides/                          vim/nvim references
keeb/                            hhkb layout notes
.agent/                          briefs + skills for agents in this repo
```

## .upgrade after a change

configs live in `src/` and are copied to `~` on upgrade. edit the repo, never the copy
(`rule.require.repo-as-source-of-truth`):

```sh
git.repo.pull             # first: update the repo from its remote
grove.provision               # then: raise this machine to what the repo declares
grove.provision.bashaliases   # just aliases
grove.provision.zshrc         # just zshrc
```

to upgrade from a worktree rather than the canonical checkout:

```sh
DEV_ENV_SETUP_DIR=<worktree> grove.provision.bashaliases
```

> `upgrade`, not `install`: no machine is ever blank — every box already ships a shell, a PATH,
> and `/etc/skel` dotfiles — so every run RAISES an extant tree, the first run included. see
> `.agent/repo=.this/role=any/briefs/domain.terms/term=grove.provision._.choice._.md`.

## .a cloud box

a headless box is a **grove**. see
`.agent/repo=.this/role=any/briefs/grove/provision/howto.provision-a-grove.md` for the reach path, the duct,
and the recovery steps — and `plan.grove-credentials.md` for how a grove gets credentials
without a secret at rest.
