# runaway-monitor.spec

## .what

desktop notification system that alerts when processes consume excessive CPU or memory, with actionable fix command.

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
| actionable fix | include `kill -9 <pids>` command ready to copy-paste |
| poll interval | check every 2 minutes (balance responsiveness vs overhead) |
| lightweight | negligible CPU/memory footprint when idle |
| persistent | survive reboots via systemd user timer |
| logged | append alerts to ~/.local/log for post-mortem |

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
| runaway-monitor | early alert before OOM territory (user decides action) |

runaway-monitor alerts *before* things get bad enough for OOM killers to act.
