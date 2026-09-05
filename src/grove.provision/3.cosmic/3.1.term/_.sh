#!/usr/bin/env bash
######################################################################
# .what = cosmic-term, at a version whose keybinds can be configured
#
# .why  it is declared at all, when 4.3.kitty is the terminal in daily use
#         cosmic-term is what COSMIC's own Terminal action opens by default, and
#         what a human gets from the app menu before any of this repo's config
#         lands. `3.3.desktop` repoints that action at kitty — but until it does,
#         and any time that override is lost, cosmic-term is the terminal a
#         desktop actually opens. so it is kept usable rather than left stale.
#
# .why  the 1.0.5 floor
#         before 1.0.5 cosmic-term read no `shortcuts_custom` file at all, so this
#         bundle's `configure` phase would write a file no reader loads — a config
#         that lands and does not apply, which is the exact defect a verify exists
#         to catch.
#
# usage:
#   rhx grove.provision --what 3.1.term --mode apply
######################################################################

grove_provision_3_1_term() {
  bundle.upgrade 3.1.term.provision.upsert
  bundle.upgrade 3.1.term.provision.verify
  bundle.upgrade 3.1.term.configure.upsert
  bundle.upgrade 3.1.term.configure.verify
}
