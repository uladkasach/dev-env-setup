#!/usr/bin/env bash
######################################################################
# .what = the runaway monitor — a systemd user timer that runs the finders every
#         2 minutes and raises a desktop notification when a threshold trips
#
# .why it DECLINES on a grove, where `1.6.1.finders` does not
#   - its whole output is `notify-send`, which needs a desktop bus a
#     headless box has none of, so its alert would reach nobody
#   - a grove can HOLD `1.6.1.finders` (stdout, read over a duct) and
#     cannot hold this (a bus that does not exist) — the effect-vs-hold
#     line, and why the two are separate bundles
#   - a headless variant that alerts through a log or a duct write is a
#     clean addition (`1.6.4.watchdog` or similar), not a change to this
#
# .how to TEAR IT DOWN, since no bundle phase removes
#   - every phase in the framework CONVERGES; none removes, so the old
#     teardown function had no home and was deleted rather than ported
#   - its four commands, recorded so the knowledge outlives the function:
#       systemctl --user disable --now runaway_monitor.timer
#       rm -f ~/.local/bin/machine_resource_procs_monitor \
#             ~/.config/systemd/user/runaway_monitor.{service,timer} \
#             ~/.local/state/runaway_monitor.cooldown
#       systemctl --user daemon-reload
#   - a later apply of this bundle re-installs all three and re-enables
#     the timer, so the teardown is a human's deliberate act, not a phase
#
# usage:
#   rhx grove.provision --what 1.6.2.monitor --mode apply
######################################################################

grove_provision_1_6_2_monitor() {
  bundle.upgrade 1.6.2.monitor.provision.upsert
  bundle.upgrade 1.6.2.monitor.provision.verify
}
