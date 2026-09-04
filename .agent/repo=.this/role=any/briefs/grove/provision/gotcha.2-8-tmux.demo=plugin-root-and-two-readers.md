# gotcha.2-8-tmux.demo=plugin-root-and-two-readers

## .what

the dated measurements behind `2.8.tmux/_.sh`'s plugin-root asker, its timeout wrap, and its
one state reader shared by both provision and verify.

## m1 — a hardcoded plugin path polled an empty dir for 90 seconds

measured on this laptop, 2026-07-30, tmux 3.4, tpm's own published answer:

```
TMUX_PLUGIN_MANAGER_PATH=/home/vlad/.config/tmux/plugins/
~/.config/tmux/plugins/  → tpm  tmux-resurrect  tmux-continuum
~/.tmux/plugins/         → tpm
```

against a hardcoded `$HOME/.tmux/plugins` path, `configure.upsert` polled an empty dir for
90s, then failed. all three plugins sat installed one directory over. the verify
repeated the same false ✋. a run that spends 92s to report an absent defect teaches a
reader to skim past ✋. tpm's choice depends on `$XDG_CONFIG_HOME`, `~/.config/tmux`, and its
own version — to re-derive that rule here is a second copy of it, free to drift — so the
reader ASKS tmux (`show-environment -g`) rather than guess.

## m2 — a bare `timeout` did not end a TERM-deaf child at 5× its limit

measured 2026-08-14 (`prove.timeouts-kill-what-they-cut`). `timeout` alone sends TERM, and a
tmux client on a wedged socket may not act on one. the plugin-root asker wraps its call with
`timeout -k 2 5`, not `timeout 5` alone, so a wedged server's grace is short — the subject is
a local socket read, not a transfer.

## m3 — two readers over one state set disagreed on two inputs at once

measured 2026-08-14: an upsert `[[ -d "$tpm_dir" ]]` beside a verify `[[ -x "$tpm_bin" ]]`
disagreed on:

1. a clone KILLED mid-flight leaves a carcass that passes `-d` forever — `git_clone` removes
   its own partial dir on any failure it observes, and a SIGKILL, an oom, or a lost duct is
   not observable
2. a tpm at the WRONG commit is invisible to `-d`, which cannot see a sha — bump the pin and
   every box that holds tpm stays put, while both halves report ✔, so the pin's own purpose
   is unmet

⇒ one state reader (`whole`/`adrift`/`half`/`absent`), asked by both halves
(`rule.require.one-command-provision`, the deterministic clause;
`gotcha.a-check-that-cries-wolf-gets-silenced`, m9).

## .see also

- `rule.require.bundle-as-sole-declaration` — the binary-beside-its-conf principle
- `rule.require.bounded-probes-in-verifies` — why the ask is timeout-wrapped
- `prove.timeouts-kill-what-they-cut` — m2's clamp
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m9, the two-readers shape m3 fixes
