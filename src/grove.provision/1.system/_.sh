#!/usr/bin/env bash
######################################################################
# .what = the box itself — keyboard, power, browser, kernel knobs
#
# .why
#   - these concerns belong to the BOX, not to a tool run on it
#   - every later section assumes them
#   - 📜 a devtool build gets oom-killed on a box with no swap
#
# .why these children
#   - each is a separable concern with its own claims to prove
#   - so `--what 1.2.power` drives alone and its verify names only its own claims
#
#     1.1.keybinds   the keyboard remap        (keyd, keynav)
#     1.2.power      never suspend, never lock (logind.conf, sleep.conf)
#     1.3.browser    which browser this box uses → 1.3.1.firefox
#     1.4.sysctl     the raised kernel parameters (/etc/sysctl.conf)
#     1.5.swap       the swapfile
#     1.6.procs      the runaway-process concern — finders, monitor, killer
#     1.7.usage      the two machine-usage report commands
#     1.8.tmpfiles   the daily /tmp prune, so boot stays fast
#
# .why there is no `1.4.performance`, and why nearly all apply to EVERY box
#   - "performance" is an OUTCOME, so no bundle can install it or own it —
#     a dir named for a quality collects whatever a writer felt was related
#     (`rule.require.bundle-names-name-their-subject`)
#   - a screen-gate reads "no EFFECT here" as "cannot be HELD here"; a
#     keyboard remap with no keyboard is a harmless declaration, so `1.1`
#     through `1.5` apply everywhere
#
# ⚠️ .why `1.6.procs` is the ONE that splits
#   - its `1.6.2.monitor` output is `notify-send`, which needs a desktop bus
#   - a grove holds no such bus, so that timer would reach nobody forever
#   - ⇒ the decline is "no bus here", never "no effect here"
#   - `1.6.1.finders` installs everywhere, and a grove needs it most
#   - the decline lives in the leaf that owns the fact (rule.require.identical-bundle-composition)
#
# usage:
#   rhx grove.provision --what 1.system --mode apply
######################################################################

grove_provision_1_system() {
  bundle.upgrade 1.1.keybinds
  bundle.upgrade 1.2.power
  bundle.upgrade 1.3.browser
  bundle.upgrade 1.4.sysctl
  bundle.upgrade 1.5.swap
  bundle.upgrade 1.6.procs
  bundle.upgrade 1.7.usage
  bundle.upgrade 1.8.tmpfiles
}
