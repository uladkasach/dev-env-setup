# F3 — the laptop `git backup` alias stays, unchanged

## .the fork

`git_alias_backup` (`src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:4017`) is a human-run,
interactive backup of `~/git` + `~/.claude` to any `--into s3://…`, one tar each, `effectiveAt=` keys.

- **A (taken)** — leave it. the grove agent is a new, separate owner, for groves only
- **B** — retire it in favor of the agent
- **C** — make the agent call it

## .why A

- the alias serves a laptop, which the agent declines (no grove role); B removes the laptop's only path
- the alias is interactive (`pv`, prompts for creds); the agent is a root timer. C fuses two contracts
- its key layout differs; a shared bucket prefix would mix two shapes

## .rework — clean

## .confidence — 85%

## .risk — safe

the taken path changes naught: the alias, its prompts, and the human's own credentials stay as
they are. no credential is added, moved, or read; no write is added.

## .verdict

—
