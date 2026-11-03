#!/usr/bin/env bash
######################################################################
# .what = the runaway-process concern, in its three answers — finders a human
#         runs, a monitor that runs them on a timer, and a killer that needs no
#         one to ask at all
#
# .why
#   - the bundles split by WHO asks, since each absence wants a different act
#   - the bodies are tracked files under `src/machine/`, so a verify can diff them
#   - each bundle, the order, and the teardown: `system.runaway_monitor.spec`
#
# usage:
#   rhx grove.provision --what 1.6.procs --mode apply
######################################################################

# .order — WRITTEN, never numeric: `1.6.5.usermanager` runs before every bundle that
#   asks `systemctl --user` (the measurement: `system.runaway_monitor.spec`)
grove_provision_1_6_procs() {
  bundle.upgrade 1.6.1.finders
  bundle.upgrade 1.6.3.earlyoom
  bundle.upgrade 1.6.5.usermanager
  bundle.upgrade 1.6.2.monitor
  bundle.upgrade 1.6.4.keyrackd
  bundle.upgrade 1.6.6.abandoned
  bundle.upgrade 1.6.7.grepsafe
}
