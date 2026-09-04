#!/usr/bin/env bash
######################################################################
# .what = the client apps — the ones a human clicks, not the ones a robot calls
#
# .why every child declines on a cloud box, gated in each leaf
#   - dropbox, protonvpn, codium, and the flatpaks are all GUI clients
#   - a grove has no screen to draw them on and no human to click them
#   - a parent gate would take the claim from its owner
#   - (rule.require.identical-bundle-composition)
#
# .why every phase here must complete unattended
#   - `--mode apply` is one command with no human present to answer it
#   - a browser, a `sudo vim`, or a `codium` that holds the run each break it
#   - a runbook is prose, and prose belongs in `guides/`, never in a driver
#
# .order
#   - `6.2.codium` runs last, since its configure drives the binary its provision put down
#   - the other three are independent of each other and of it
#
# .why every app here is opt-in, and a run installs none unasked
#   - a client a human clicks is a PREFERENCE, where every other bundle is a FACT
#   - the tree declares what is available, and `--include` declares what is wanted
#   - (`GROVE_OPTIN_APPS`, `src/bundle.upgrade.sh`)
#   - the section still RUNS, and an app nobody asked for prints a 🌙 decline
#   - ⚠️ the opt-in gate is per-APP, and the decline gate above is per-BOX
#
# usage:
#   rhx grove.provision --what 6.apps --mode apply     # visits, installs none
#   rhx grove.provision --include codium --mode apply  # opts one in
######################################################################

grove_provision_6_apps() {
  bundle.upgrade 6.1.flatpaks
  bundle.upgrade 6.3.dropbox
  bundle.upgrade 6.4.protonvpn
  bundle.upgrade 6.5.onepassword
  bundle.upgrade 6.2.codium
}
