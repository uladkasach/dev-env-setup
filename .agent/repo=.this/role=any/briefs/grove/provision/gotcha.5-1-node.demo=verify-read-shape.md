# demo: 5.1.node/provision.verify.sh — a box-wide fact, not a shell's

## .what

the verify's default-node check reads `fnm list`, never `fnm current`. one measurement
backs the choice.

## m1 — `fnm current` answers the CALLING SHELL, not the box, 2026-08-12

- with no `eval "$(fnm env)"` applied, a bare ssh call errored:
  ```
  $ ssh <seat> '$HOME/.local/share/fnm/fnm current'
  error: `fnm env` was not applied in this context.
  ```
- that error lands on stderr with a non-zero exit. `2>/dev/null` reads back EMPTY
- the same box's `fnm list` answered `* v24.19.0 lts-latest, default` in the same breath
- ⇒ `eval "$(fnm env)"` lives in ~/.zshrc, read by an INTERACTIVE shell only. a
  `fnm current` bar cries ✋ on every non-interactive provision and clears only from a
  human's terminal — the shape that makes a second apply look necessary
  (`rule.require.one-command-provision`, `gotcha.a-check-that-cries-wolf-gets-silenced`)

## .see also

- `5.1.node/provision.verify.sh` — the header this measurement backs
- `gotcha.5-1-node.demo=fnm-pnpm-install-measurements` — the neighbor demo, the upsert half
- `gotcha.5-1-node.demo=pnpm-shim-dir-split` — the shim-dir measurements this file also cites
