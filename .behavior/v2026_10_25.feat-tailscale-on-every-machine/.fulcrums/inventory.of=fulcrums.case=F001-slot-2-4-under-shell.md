# F001 — bundle at `2.4.tailscale`, under `2.shell`

- **fork:** `2.4` under `2.shell` (beside `2.3.ssh`) · a slot under `1.system` (a network daemon) · `5.devtools`
- **taken, why:** the tailnet is how ssh reaches a remote grove, so it sits beside `2.3.ssh`; slot 2.4 is free and dispatches after `2.1.toolkit`, which owns `curl`/`gnupg`/`jq`
- **rework:** clean — a slug rename plus one dispatch line
- **confidence 80%, why low:** `1.system` holds other daemons (keyd, earlyoom); the section choice is taste with no rule behind it
- **where:** vision `.the contract` §2

## .verdict — 5.1.execution, 2026-10-26

reworked to `5.23.tailscale`, under `5.devtools`, dispatched after `5.22.waypipe` and before `5.16.keys`. the tagged join reads its key through `rhx` and the rack, which land at `5.3.brains` and `5.12.rack`; a `2.shell` slot would run first on a fresh grove and owe a second apply (`rule.require.one-command-provision`). `2.shell`'s 2.4 slot is empty by declaration and stays so. rework was clean: no box state keys on the slug.