#!/usr/bin/env bash
######################################################################
# .what = the kitty session snapshot — the low-battery guard, its systemd user
#         unit, and the timer that polls for a descent
#
# .why it exists
#   - a reopened kitty window loses its MAP — which directory it stood in,
#     what ran there — and a human cannot recall ten paths from memory
#   - the snap records that map from `/proc` alone, read back by
#     `howto.restore-kitty-session.md`
#
# .why it sits under 4.3.kitty, and declines where its parent does not
#   - it reads kitty's process tree and writes `~/.kitty/snaps`, so it
#     moves with the emulator if that ever swaps
#     (`rule.require.bundle-names-name-their-subject`)
#   - it captures WINDOWS and polls a BATTERY, and a grove has neither —
#     its parent `4.3.2.emulator` does not decline, since the tarball it
#     ships still drives a grove; this child does
#
# .why the TIMER is a bundle concern and the alias is not
#   - `kitty.snap`, `power.off`, `power.restart` live in `src/bash_aliases.sh`,
#     owned by `2.7.aliases` (`rule.forbid.two-writers-on-one-artifact`)
#   - this bundle owns the part no alias can carry: a guard that fires
#     when the human is not at the keyboard
#
# .the gap this closes
#   - `install_kitty_snap_hooks` was reached by exactly one caller, a
#     since-retired alias a human had to type, so a fresh box got the
#     alias and NOT the timer (`rule.require.every-function-has-a-driver`)
#
# usage:
#   rhx grove.provision --what 4.3.4.snapshot --mode apply
######################################################################

grove_provision_4_3_4_snapshot() {
  bundle.upgrade 4.3.4.snapshot.provision.upsert
  bundle.upgrade 4.3.4.snapshot.provision.verify
}
