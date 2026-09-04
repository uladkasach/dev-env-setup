# howto.restore-kitty-session

## .what

how to snapshot every open kitty window and later restore the same layout —
the cwd of each window (and each tmux pane) — after a reboot, crash, or
deliberate close.

## .why

- a workday spreads across ~20 kitty windows, each parked in a different
  worktree; a reboot loses that map
- the snap records where you were so you can pick the work back up fast
- tmux sessions survive a kitty restart, but you still need to know which
  session belonged to which window

## .the tool

| where | what |
|-------|------|
| `src/machine/kitty.snapshot.terminals.sh` | the implementation — a declared asset |
| `~/.local/bin/kitty.snap` | where `4.3.4.snapshot` installs it |
| `kitty.snap` | the alias, owned by `2.7.aliases` |
| `rhx kitty.snapshot.terminals` | a shim onto the checkout copy, for a repo where the install has not run |

it reads only `/proc` (never kitty remote control, never env) plus read-only
`tmux list-*`. see `rule.require.security-paramount.md`.

## .take a snapshot

```sh
kitty.snap
```

this prints the tree and saves two files to `~/.kitty/snaps/`:

| file | purpose |
|------|---------|
| `<timestamp>.txt` | readable tree — eyeball "what was i on" |
| `<timestamp>.json` | structured record — drives the restore below |

each json entry holds: `kitty_pid`, `pid`, `comm`, `cwd`, `program`,
`age_seconds`, `rss_kb`. tmux panes appear with `comm=tmux` and their real
`cwd` (the pane path, not the client's).

tip: snap before a reboot, or on a cron, so a recent map always exists.

## .find the snap you want

```sh
ls -t ~/.kitty/snaps/*.json | head        # most recent first
cat ~/.kitty/snaps/2026-07-27T00-19-11.txt # read a specific one
```

## .restore the layout

restore reopens a terminal at each saved cwd. because `allow_remote_control`
stays `no` by default (security), restore spawns fresh kitty windows with
`kitty --directory` rather than inject tabs over a socket.

reopen one kitty window per distinct cwd:

```sh
snap=~/.kitty/snaps/2026-07-27T00-19-11.json
jq -r '.[].cwd' "$snap" | sort -u | while read -r dir; do
  [ -d "$dir" ] && kitty --directory "$dir" &
done
```

the `[ -d "$dir" ]` guard skips worktrees that no longer exist.

## .restore tmux windows

the tmux server usually outlives a kitty restart, so the sessions are still
there — you only need to reattach. the snap's `.txt` shows which cwd each tmux
window held; list live sessions and reattach:

```sh
tmux list-sessions
kitty --directory "$dir" -- tmux attach -t "<session>"
```

if the tmux server was also lost (full reboot without a resurrect plugin),
treat those entries like any other cwd and reopen a plain shell there.

## .what restore does NOT do

restore puts you back in the right **directories**. it does not resurrect
**program state** — a claude session, an active build, an editor's unsaved
buffers are gone once the process exits. the snap is a map, not a memory dump.

for editors, rely on their own recovery (nvim swap/session files). for tmux,
rely on the persisted server or a resurrect plugin.

## .automatic snaps before the machine dies

so the map is never lost, a snap fires automatically on two triggers, which two
DIFFERENT bundles own:

| trigger | mechanism | owner | reliability |
|---------|-----------|-------|-------------|
| battery descends past 10%, then 5% | `kitty_snap_lowbatt` systemd user timer polls every 3 min; two stages, each snaps once per discharge episode, only on the way down | `4.3.4.snapshot` | reliable — kitty still alive |
| cli reboot / shutdown | `power.off` / `power.restart` aliases snap first | `2.7.aliases`, via `src/bash_aliases.sh` | reliable — kitty still alive |

⚠️ the split is deliberate, not an oversight. one file may have one writer
(`rule.forbid.two-writers-on-one-artifact`), and `src/bash_aliases.sh` already
has one. so the bundle owns the part no alias can carry — a guard that fires
when the human is not at the keyboard — and the aliases own the by-hand snap.

⚠️ BOTH triggers call the same installed path, `~/.local/bin/kitty.snap`, which
`4.3.4.snapshot` puts there from `src/machine/`. so `2.7.aliases` alone is not
enough: an alias applied without the bundle names a file no phase installed.
that is why the block below drives both. 🛑 the snapper stays a `src/` asset
because a bundle owns its own payload — under `.agent/` it sat outside the
deployable unit, and a box got both callers and no snapper
(`rule.require.bundles-own-their-dependencies`).

establish both through the one entrypoint (never a one-off):

```sh
rhx grove.provision --what 4.3.4.snapshot --mode apply   # the timer
rhx grove.provision --what 2.7.aliases   --mode apply   # kitty.snap + power.*
```

a full `grove.provision` drives both, so a whole-tree run establishes them too.

note: gui-menu reboots are not caught — the graphical session (and kitty) is
often torn down before a shutdown hook could run, so the snap would be empty.
use `power.restart` / `power.off` from a terminal to guarantee a snap.

## .see also

- `src/machine/kitty.snapshot.terminals.sh` — the implementation, owned by `4.3.4.snapshot`
- `rule.require.security-paramount.md` — why reads stay `/proc`-only, no env
- `howto.terminal-window-management.md`
- `termwork.sh` — the repo's kitty spawn-with-socket mechanism