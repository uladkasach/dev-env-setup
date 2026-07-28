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

skill: `.agent/repo=.this/role=any/skills/kitty.snapshot.terminals.sh`
alias: `kitty.snap` (activate via `sync.devenv.bashaliases`)

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

so the map is never lost, a snap fires automatically on two triggers, both
installed by `install_kitty_snap_hooks` in `install_env.pt1.system.performance.sh`:

| trigger | mechanism | reliability |
|---------|-----------|-------------|
| battery descends past 10%, then 5% | `kitty_snap_lowbatt` systemd user timer polls every 3 min; two stages, each snaps once per discharge episode, only on the way down | reliable — kitty still alive |
| cli reboot / shutdown | `power.off` / `power.restart` aliases snap first | reliable — kitty still alive |

activate via the repo's install procedure (never a one-off):

```sh
sync.devenv.cronhooks   # installs the user timers (kitty snap + runaway monitor)
```

`sync.devenv` also runs this as its last step, so a full sync establishes it too.

note: gui-menu reboots are not caught — the graphical session (and kitty) is
often torn down before a shutdown hook could run, so the snap would be empty.
use `power.restart` / `power.off` from a terminal to guarantee a snap.

## .see also

- `kitty.snapshot.terminals.sh` — the skill
- `rule.require.security-paramount.md` — why reads stay `/proc`-only, no env
- `howto.terminal-window-management.md`
- `termwork.sh` — the repo's kitty spawn-with-socket mechanism
