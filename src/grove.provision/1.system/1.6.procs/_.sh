#!/usr/bin/env bash
######################################################################
# .what = the runaway-process concern: find it, watch for it, kill it, and keep
#         the seat and its evidence alive through it — one leaf per answer
#
# .why the bodies are TRACKED FILES under `src/machine/`, not heredocs
#   - a heredoc gets no lint and no syntax-check
#   - a verify diffs installed bytes against `$GROVE_SRC` (`rule.require.repo-as-source-of-truth`)
#
# .why one leaf per answer, split by WHO asks
#   - `1.6.1.finders` — a human, on demand; a wedged grove needs them most
#   - `1.6.2.monitor` — a timer, alerts via `notify-send`; declines on a grove (no desktop bus)
#   - `1.6.3.earlyoom` — no one asks; its output is the KILL, so it applies everywhere
#   - `1.6.4.keyrackd` — a timer, over the leaked keyrack daemons
#   - `1.6.5.usermanager` — the aftermath: a killed user manager is started again
#   - `1.6.6.abandoned` — a timer, hourly: kill each process abandoned for over 24h
#   - `1.6.7.linger` — every human seat lingers, so its user manager and crew scopes
#     outlive the last logout
#   - `1.6.8.coredump` — a crash leaves a core, so the next one is read, not guessed
#   - earlyoom earns its own leaf: an absent finder leaves a box undiagnosable, an
#     absent earlyoom leaves it unreachable
#
# .the follow-on this leaves open
#   - no `del` phase exists, so `uninstall_runaway_monitor`'s teardown sits in
#     `1.6.2.monitor/_.sh` for a human
#
# usage:
#   rhx grove.provision --what 1.6.procs --mode apply
######################################################################

# .order — WRITTEN order, never numeric
#   - `1.6.7.linger` first, and `1.6.5.usermanager` before every leaf that asks
#     `systemctl --user` (monitor, keyrackd, abandoned): each leans on a live user manager
#   - measured 2026-10-07: in numeric order the revive ran after monitor and keyrackd, and
#     both failed `daemon-reload` on a dead bus (`define.provision-defect-shapes`, shape 1)
grove_provision_1_6_procs() {
  bundle.upgrade 1.6.7.linger
  bundle.upgrade 1.6.8.coredump
  bundle.upgrade 1.6.1.finders
  bundle.upgrade 1.6.3.earlyoom
  bundle.upgrade 1.6.5.usermanager
  bundle.upgrade 1.6.2.monitor
  bundle.upgrade 1.6.4.keyrackd
  bundle.upgrade 1.6.6.abandoned
}
