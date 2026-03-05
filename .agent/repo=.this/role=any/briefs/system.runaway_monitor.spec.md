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
| auto-kill | too dangerous; user decides what to kill |
| email alerts | desktop notification sufficient for dev machine |
| web UI | overkill; notification + log sufficient |
| process restart | not a server; just need awareness |

## .complements

| tool | role |
|------|------|
| systemd-oomd / earlyoom | last-resort OOM prevention (kills biggest hog when critical) |
| runaway_monitor | early alert before OOM territory (user decides action) |

runaway_monitor alerts *before* things get bad enough for OOM killers to act.
