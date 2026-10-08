#!/usr/bin/env bash
######################################################################
# .what = the runaway-process concern, in its three answers — finders a human
#         runs, a monitor that runs them on a timer, and a killer that needs no
#         one to ask at all
#
# .why the bodies are TRACKED FILES, not heredocs
#   - a quoted heredoc gets no lint, no syntax-check, and a one-line fix
#     diffs as the whole upgrader
#   - they live under `src/machine/`, and each phase copies from
#     `$GROVE_SRC`, which lets a verify diff installed bytes against
#     declared ones (`rule.require.repo-as-source-of-truth`)
#
# .why four leaves, split by WHO asks
#   - `1.6.1.finders` — a human asks, on demand; applies everywhere, and a
#     grove that wedges needs them MORE, since no human sits at it
#   - `1.6.2.monitor` — a timer asks, and alerts through `notify-send`,
#     which needs a desktop bus, so it declines on a grove
#   - `1.6.3.earlyoom` — no one asks; its output is the KILL, needs no
#     screen, so it applies everywhere and a grove needs it most
#   - `1.6.4.keyrackd` — a timer asks, and its subject is a SECOND population:
#     the leaked keyrack daemons. it needs no screen either, and it declines
#     when this checkout does not carry the prune skill
#   - `1.6.5.usermanager` — the AFTERMATH: when a kill (or a crash) takes the
#     user's systemd manager, the system manager starts it again, so the
#     session bus every `systemd-run --user` caller needs comes back
#   - `1.6.6.abandoned` — a timer asks, hourly: kill and log each process
#     abandoned for over 24h, so the orphan POPULATION earlyoom cannot see
#     never builds up
#   - an absent finder means a wedged box cannot be DIAGNOSED; an absent
#     earlyoom means it cannot be REACHED — two failures a reader acts on
#     differently, which is why earlyoom earns its own leaf
#
# .the follow-on this leaves open
#   - no `del` phase exists in the framework, so the old
#     `uninstall_runaway_monitor`'s four commands sit recorded in
#     `1.6.2.monitor/_.sh` for a human who wants the teardown
#
# usage:
#   rhx grove.provision --what 1.6.procs --mode apply
######################################################################

# .order — WRITTEN order, never numeric: `1.6.5.usermanager` runs BEFORE every leaf
#   that asks `systemctl --user` (monitor, keyrackd, abandoned). measured 2026-10-07:
#   in numeric order, the revive ran after monitor and keyrackd, so on a box whose
#   manager was dead both failed `daemon-reload` with "Failed to connect to bus",
#   while the revive two lines later brought the bus back
#   (`define.provision-defect-shapes`, shape 1)
grove_provision_1_6_procs() {
  bundle.upgrade 1.6.1.finders
  bundle.upgrade 1.6.3.earlyoom
  bundle.upgrade 1.6.5.usermanager
  bundle.upgrade 1.6.2.monitor
  bundle.upgrade 1.6.4.keyrackd
  bundle.upgrade 1.6.6.abandoned
}
