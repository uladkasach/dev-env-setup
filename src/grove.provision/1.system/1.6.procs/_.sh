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
# .why three leaves, split by WHO asks
#   - `1.6.1.finders` — a human asks, on demand; applies everywhere, and a
#     grove that wedges needs them MORE, since no human sits at it
#   - `1.6.2.monitor` — a timer asks, and alerts through `notify-send`,
#     which needs a desktop bus, so it declines on a grove
#   - `1.6.3.earlyoom` — no one asks; its output is the KILL, needs no
#     screen, so it applies everywhere and a grove needs it most
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

grove_provision_1_6_procs() {
  bundle.upgrade 1.6.1.finders
  bundle.upgrade 1.6.2.monitor
  bundle.upgrade 1.6.3.earlyoom
}
