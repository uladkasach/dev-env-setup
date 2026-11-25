#!/usr/bin/env bash
######################################################################
# .what = the runaway-process concern: find it, watch for it, kill it, and keep
#         the seat and its evidence alive through it — one leaf per answer
#
# .why
#   - the bundles split by WHO asks, since each absence wants a different act
#   - the bodies are tracked files under `src/machine/`, so a verify can diff them
#   - each bundle, the order, and the teardown: `system.runaway_monitor.spec`
#   - `1.6.9.linger` is the SEAT's half: every human seat lingers, so each crew
#     scope outlives the last logout. `1.6.8.coredump` keeps each crash's core
#
# usage:
#   rhx grove.provision --what 1.6.procs --mode apply
######################################################################

# .order — WRITTEN, never numeric: `1.6.9.linger` runs first, since every bundle that
#   asks `systemctl --user` leans on it; `1.6.5.usermanager` runs before each of them
#   (the measurement: `system.runaway_monitor.spec`)
grove_provision_1_6_procs() {
  bundle.upgrade 1.6.9.linger
  bundle.upgrade 1.6.8.coredump
  bundle.upgrade 1.6.1.finders
  bundle.upgrade 1.6.3.earlyoom
  bundle.upgrade 1.6.5.usermanager
  bundle.upgrade 1.6.2.monitor
  bundle.upgrade 1.6.4.keyrackd
  bundle.upgrade 1.6.6.abandoned
  bundle.upgrade 1.6.7.grepsafe
}
