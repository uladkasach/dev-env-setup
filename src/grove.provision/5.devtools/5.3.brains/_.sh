#!/usr/bin/env bash
######################################################################
# .what = the robot brains — claude-code, rhachet, and codex, plus their config
#
# .why no phase CALLS another
#   - a delegated install-then-configure reports the CONFIG's status only,
#     so a failed install can read ✔ (`rule.forbid.failhide`)
#   - each phase installs or configures and returns its own status
#     (`rule.require.bundle-as-sole-declaration`)
#
# .why every machine, no decline
#   - a grove runs the brains too
#
# usage:
#   rhx grove.provision --what 5.3.brains --mode apply
######################################################################

####################################################################
# the brain pins — ONE declaration each, read by BOTH halves
#
# .why here, never beside the install
#   - the verify reads the LIVE BINARY against this same value
#     (`gotcha.a-check-that-cries-wolf`, m.9 / m.13)
#
# .why the criterion is WHO CAN PUBLISH
#   - first-party (rhachet, declastruct) is this org's own account;
#     third-party (codex, claude-code) is somebody else's, reached
#     by every box that floats it — the first-party float is accepted
#   - a top-level pin bounds only this package, never its dependency tree
#
# .why claude is `2.1.87`, not latest, and the verify asks the BINARY
#   - hooks are TRUNCATED beyond it (`define.claude-code-config.md`)
#   - claude's in-place updater rewrites `cli.js` and leaves the
#     package metadata behind, so a package-only check misses drift
#
# .refs = gotcha.5-3-brains-pins.demo=publish-path-and-drift.md
#
# .how to bump = a decision, so two steps, never one:
#   npm view @openai/codex version
#   codex --version
####################################################################
GROVE_BRAIN_CLAUDE_PIN="2.1.87"
GROVE_BRAIN_CODEX_PIN="0.128.0"

grove_provision_5_3_brains() {
  bundle.upgrade 5.3.brains.provision.upsert
  bundle.upgrade 5.3.brains.provision.verify
  bundle.upgrade 5.3.brains.configure.upsert
  bundle.upgrade 5.3.brains.configure.verify
}
