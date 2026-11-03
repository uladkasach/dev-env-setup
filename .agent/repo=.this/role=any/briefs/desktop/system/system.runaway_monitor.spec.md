# runaway_monitor.spec

## .what

desktop notification system that alerts when:
1. processes consume excessive CPU or memory (every 2 min)
2. orphan processes exist from deleted directories (every 1 hr)

## .why

dev machines run memory-hungry tools (nvim, node, claude, browsers). when one spins out:
- system becomes sluggish before user notices
- by the time it's obvious, UI is unresponsive
- user has to guess which process to kill
- worst case: OOM freeze requires hard reboot

early detection + actionable notification = fix in 5 seconds instead of 5 minutes of frustration.

## .requirements

| req | description |
|-----|-------------|
| cpu threshold | alert when load average > 1.5x CPU cores |
| memory threshold | alert when available memory < 15% |
| desktop notification | use notify-send with critical urgency |
| identify offenders | show top 3-4 processes by CPU and memory |
| actionable fix | include `kill -9 <pids>` command for each breached threshold (CPU and/or MEM) |
| poll interval | check every 2 minutes (balance responsiveness vs overhead) |
| cooldown | 10 minutes between alerts (clears when system recovers) |
| lightweight | negligible CPU/memory footprint when idle |
| persistent | survive reboots via systemd user timer |
| logged | systemd journal via logger (query: `journalctl --user -t runaway_monitor`) |
| orphan detection | alert on processes whose cwd was deleted (e.g., deleted worktrees) |
| orphan interval | check orphans every 1 hour (less urgent than resource alerts) |

## .commands

| command | description |
|---------|-------------|
| `machine_resource_procs_find_runaway` | check CPU/memory, show offenders if thresholds breached |
| `machine_resource_procs_find_runaway --json` | machine-readable output for automation |
| `machine_resource_procs_find_runaway --kill cpu` | kill top 3 CPU-consuming processes |
| `machine_resource_procs_find_runaway --kill mem` | kill top 3 memory-consuming processes |
| `machine_resource_procs_find_runaway --kill <prefix>` | kill processes with prefix (e.g., `--kill nvim`) |
| `machine_resource_procs_find_runaway --kill <prefix> cpu` | kill prefix processes from CPU list only (e.g., `--kill nvim cpu`) |
| `machine_resource_procs_find_runaway --kill <prefix> mem` | kill prefix processes from MEM list only (e.g., `--kill nvim mem`) |
| `machine_resource_procs_find_orphan` | find processes whose cwd was deleted |
| `machine_resource_procs_find_orphan --kill` | kill all orphan processes |
| `machine_resource_procs_find_orphan --kill <prefix>` | kill orphan processes with prefix (e.g., `--kill node`) |
| `machine_resource_procs_find_spinner` | find processes with sustained high CPU (>50% ratio for 30+ min) |
| `machine_resource_procs_find_spinner --kill` | kill all spinner processes |
| `machine_resource_procs_find_spinner --kill <prefix>` | kill spinner processes with prefix (e.g., `--kill nvim`) |
| `machine_resource_procs_find_spinner --min-minutes N` | adjust elapsed time threshold (default: 30) |
| `machine_resource_procs_find_spinner --min-ratio N` | adjust CPU ratio threshold % (default: 50) |

## .non-requirements

| not needed | why |
|------------|-----|
| auto-kill | too dangerous; user decides what to kill — except a grepsafe run older than 2min, whose kill is settled (`1.6.7.grepsafe`) |
| email alerts | desktop notification sufficient for dev machine |
| web UI | overkill; notification + log sufficient |
| process restart | not a server; just need awareness |

## .complements

| tool | role |
|------|------|
| systemd-oomd / earlyoom | last-resort OOM prevention (kills biggest hog when critical) |
| runaway_monitor | early alert before OOM territory (user decides action) |

runaway_monitor alerts *before* things get bad enough for OOM killers to act.

## .the `1.6.procs` bundles, split by WHO asks

| bundle | who acts | where |
|---|---|---|
| `1.6.1.finders` | a human ASKS what consumes the box | everywhere. a grove that wedges needs them MORE, since no human sits at it |
| `1.6.2.monitor` | a timer asks on the human's behalf, and alerts via `notify-send` | declines on a grove: it needs a desktop bus |
| `1.6.3.earlyoom` | no one asks: the daemon kills | everywhere. a grove needs it most |
| `1.6.4.keyrackd` | a timer asks, about a SECOND population: leaked keyrack daemons | declines when the checkout lacks the prune skill |
| `1.6.5.usermanager` | the AFTERMATH: the system manager restarts a killed or crashed user manager | brings back the session bus every `systemd-run --user` caller needs |
| `1.6.6.abandoned` | a timer asks, hourly: kill and log each process abandoned for over 24h | so the orphan POPULATION earlyoom cannot see never builds up |
| `1.6.7.grepsafe` | a timer asks, every minute: kill and log each grepsafe run older than 2min | the one population whose kill is SETTLED, so no human decides; a minute's delay costs gigabytes |

- the bodies are TRACKED FILES under `src/machine/`, never heredocs
  - a quoted heredoc gets no lint and no syntax-check, and a one-line fix diffs as the whole upgrader
  - each phase copies from `$GROVE_SRC`, so a verify diffs installed bytes against declared ones
    (`rule.require.repo-as-source-of-truth`)
- the dispatch order is WRITTEN, never numeric: `1.6.5.usermanager` runs before every bundle that
  asks `systemctl --user` (monitor, keyrackd, abandoned)
  - measured 2026-10-07: in numeric order, the revive ran after monitor and keyrackd. on a box whose
    manager was dead, both failed `daemon-reload` with "Failed to connect to bus", while the revive
    two lines later brought the bus back (`define.provision-defect-shapes`, shape 1)
- no `del` phase exists in the framework, so the old `uninstall_runaway_monitor`'s four commands
  sit recorded in `1.6.2.monitor/_.sh` for a human who wants the teardown

- they fail apart, and a reader must act differently on each
  - an absent finder means a wedged box cannot be diagnosed
  - an absent earlyoom means a wedged box cannot be REACHED to run the finder
  - ⇒ the split test holds (`rule.require.bundle-names-name-their-subject`)
- a grove needs earlyoom MOST
  - linux's own oom killer fires only once the box already thrashes
  - by then sshd cannot get scheduled, so a headless box drops off the network
  - the only cure is then a hard stop from the console. earlyoom acts while the box still answers
- so `1.6.3.earlyoom` carries NO decline, the mirror of `1.6.2.monitor`
  - the monitor declines on a grove, since its output needs a human's screen
  - earlyoom's output IS the kill, and a kernel needs no screen
