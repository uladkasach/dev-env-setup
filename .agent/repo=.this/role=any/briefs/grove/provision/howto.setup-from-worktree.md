# howto: run grove.provision from a worktree

## .what

**just run the worktree's own driver.** it locates its own `src/`, so a worktree needs no
setup at all:

```bash
cd ~/git/more/_worktrees/dev-env-setup.<branch>
rhx grove.provision --what 2.8.tmux --mode apply
```

the run prints which `src/` it read, so you can confirm it at a glance:

```
🌱 grove.provision --mode apply
   ├─ access prep · server cloud@aws.ec2 · commit none@none
   ├─ src: /home/…/_worktrees/dev-env-setup.<branch>/src     ← read this line
```

## .why it self-locates

`src/grove.provision._.sh` derives `GROVE_SRC` from its own path:

```sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${DEV_ENV_SETUP_DIR:+$DEV_ENV_SETUP_DIR/src}"
SRC="${SRC:-$HERE}"
export GROVE_SRC="$SRC"
```

every phase reads `$GROVE_SRC`, never a hardcoded `~/git/more/dev-env-setup`. so the copy you
invoked is the copy that gets read — configs included.

## 🛑 .the shape to refuse

```bash
export DEV_ENV_SETUP_DIR=~/git/more/_worktrees/dev-env-setup.<branch>
source $DEV_ENV_SETUP_DIR/src/<a part file>
<a bare function name>
```

wrong in two ways, and the second is the one that bites:

1. `source` + call is a one-off command, which `rule.require.install-via-procedures` forbids —
   it skips the bundle's verify entirely.
2. **the export carries the whole load, and is easy to forget.** miss it and the call silently
   reads `~/git/more/dev-env-setup/src` — the MAIN checkout — so you edit a config in your
   worktree, run the install, and install the old file. green output, wrong bytes.

⇒ the cure is not a better instruction. the driver derives its own `src/`, so that failure
mode has no way to occur (`rule.require.solve-at-cause`). a step a human must remember is a
step a human will forget.

## .the override still works

`DEV_ENV_SETUP_DIR` is honored, and takes precedence, for the case where you invoke one
checkout's driver but want another checkout's `src/`:

```bash
DEV_ENV_SETUP_DIR=~/git/more/_worktrees/dev-env-setup.<branch> \
  rhx grove.provision --from main --what 2.8.tmux --mode apply
```

that is rare. prefer the plain form — `cd` to the worktree and `rhx grove.provision`, which
defaults to `--from tree`.

## .the check

whichever form you use, the `src:` line in the header is the proof. if it does not name the
tree you edited, stop — the run is about to install the wrong bytes.

## .see also

- `howto.install-configs-from-a-worktree.md` — the same concern, for config artifacts
- `rule.require.install-via-procedures` — why `source` + call is forbidden
- `rule.require.solve-at-cause` — remove the failure mode, do not document around it
