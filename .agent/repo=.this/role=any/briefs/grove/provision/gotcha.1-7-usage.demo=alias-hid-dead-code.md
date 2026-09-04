# demo: 1.7.usage — an alias hid dead code

## .what

one measurement (2026-07-30) shows why `1.7.usage` had to exist: two aliases
pointed at commands no driven step ever installed.

## the trace

`src/bash_aliases.sh` had declared these two for a long time:

```
alias machine.usage.observe='machine_resource_observe'
alias machine.usage.snapshot='machine_usage_snapshot'
```

no driven step ever installed either command. the two functions that would have
were declared where no driver ever reached them — dead code, for as long as they
existed (`rule.require.every-function-has-a-driver`).

measured on this laptop 2026-07-30: `machine_resource_observe` was ABSENT from
`~/.local/bin` entirely. `machine.usage.observe` resolved as an alias and printed
"command not found". a human read that as their own typo rather than as an
install that never ran.

## the sharpest part

an ALIAS makes dead code look LIVE. the name resolves; no part of it reads as
absent until it is run. `.agent/.../skills/machine.diagnose.lag.sh` even told a
human to source a file and call the function by hand — the one-off command
`rule.require.install-via-procedures` forbids.

## .see also

- `1.7.usage/_.sh` — the bundle this measurement justified
- `rule.require.every-function-has-a-driver`
- `rule.require.install-via-procedures`
