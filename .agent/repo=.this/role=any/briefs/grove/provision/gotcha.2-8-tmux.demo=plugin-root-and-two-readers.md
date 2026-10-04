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

## m4 — a box holds MORE THAN ONE tmux server, and the count is not the claim

- a conf is read at SERVER start, so each server holds its own copy IN MEMORY. a write to
  `~/.tmux.conf` reaches zero live servers, and a source into the DEFAULT socket reaches one
- 📜 2026-09-13, this laptop: **16 sockets** — the duct server, a `copygate`, and 14 probe
  corpses left by `prove.*` plays. small, and not one: a phase that converges only `default`
  leaves the rest adrift
- ⚠️ the ducts are SESSIONS on one server, not a server each — ductwork addresses
  `-t "$DUCT_SESSION"`, so 74 ducts shared one socket. a prior draft claimed one `-L` server
  per duct and was wrong. that changes the MAGNITUDE and not the claim: a live server still
  holds an in-memory conf, and a removed plugin's option outlives its `@plugin` line
- the SOCKET DIR (`${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/`) is the inventory, so no second list
  can drift from it. never `tmux ls` — it speaks to ONE server and reports its SESSIONS

## m5 — the plugin install needs an ISOLATED server, never a new session (grove-1, 2026-07-30)

tpm's `install_plugins` reads the plugin list from a SERVER that loaded the conf — it is no
standalone fetcher — and tmux reads `~/.tmux.conf` at SERVER start, never at session creation.
`tmux new-session -d -s _tpm_init` works on a box with no tmux up, since the session starts a
server that reads the fresh conf. on a GROVE the duct IS tmux, so a server is always up, and
`new-session` joined it with its OLD config:

| approach                                   | plugins landed |
|--------------------------------------------|----------------|
| new-session on the extant server (old)     | none, exit 1   |
| isolated server with `-f ~/.tmux.conf`     | both ✔         |

`tmux show-options -g | grep plugin` on the live server returned EMPTY.

- an isolated SOCKET (`-L`) removes a hazard a reserved session name only avoided: on a grove
  this phase often runs INSIDE a duct session, and a `kill-session` could tear down the channel
  the run speaks over. a separate server shares no session namespace with it
- 📜 an interrupted run left `_tpm_init` alive, and the next start read "duplicate session" —
  `kill-server` on a socket only this phase uses is unconditionally safe
- the plugins are POLLED on disk: `run-shell` dispatches into a pane, so its exit code reports
  the dispatch, never the clone (`rule.require.upgrade-entries-verify-themselves`). the 30s bound
  covers the dispatch, and the poll has its own 90s
- every tmux call is BOUNDED: a client waits on the server's socket, and a server wedged on a hung
  pane never replies. the cleanup call exists BECAUSE a prior run left a server behind, so it is
  the one most apt to meet a wedge

## m6 — the conf IS sourced into the live server (grove-ahbode-v20260901, 2026-09-03)

three prior reasons to decline, each measured:

1. "a re-run of tpm re-inits a plugin's hooks" — REFUTED. after three sources,
   `status-right "#(…/continuum_save.sh) #{@branch} "` held ONE hook. (measured while the conf
   still carried continuum; the claim is about TPM, so the probe plugin is incidental)
2. "a conf that does not parse breaks the duct" — STALE: the isolated server runs `-f
   ~/.tmux.conf` and returns 1 on a bad conf, so by the source the conf is PROVEN to parse
3. `set -as` APPENDS — REAL, and the one cost that survives: the feature list gains 3 entries
   per source (`[2..4] [5..7] [8..10] xterm-kitty:extkeys/clipboard/RGB`). COSMETIC, since tmux
   applies the same features either way — cheaper than a config that never reaches the server

⚠️ the source is HALF the job: `terminal-features` is negotiated at CLIENT ATTACH. 📜 RGB was set
server-side and both clients still read `feats=…` with no RGB. so the phase names the REATTACH a
live client needs — a source reported as "done" would be a failhide.

## m7 — into EVERY live server, since an option outlives the line that asked for it

📜 2026-09-13, this laptop: tmux-continuum was removed from the conf, and the save storm did not
stop — every live server still carried continuum's `status-right`, the interpolation that FIRES
the save on each refresh. the removal reached only servers booted after it.

- ⇒ an un-sourced server does not merely hold stale values: it still RUNS what the conf no longer
  declares. a default-only source converges whichever server happened to be `default` (m4: 16
  sockets that day). the conf sets `status-right` explicitly, so one source overwrites it
- a FAILED socket does not fail the phase: a socket file can outlive its server, and neither is a
  defect in the conf. they are counted and named; the verify grades them
- an ABSENT server is a pass — the next one reads the file fresh

## .see also

- `rule.require.bundle-as-sole-declaration` — the binary-beside-its-conf principle
- `rule.require.bounded-probes-in-verifies` — why the ask is timeout-wrapped
- `prove.timeouts-kill-what-they-cut` — m2's clamp
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m9, the two-readers shape m3 fixes
