#!/usr/bin/env bash
######################################################################
# .what = COSMIC's shell layout — keybinds, the terminal action, the panel,
#         autotile, and the idle timers
#
# .five unlike settings in ONE bundle
#   - each writes a different file under `~/.config/cosmic/`
#   - together they are one claim: this desktop behaves as this repo declares
#   - every failure has one cause (the config dir) and one fix (re-apply)
#
# ⚠️ .the power keybinds are deliberately disabled
#   - COSMIC's PowerOff / Suspend / LogOut actions are rewritten to `true`
#   - those keys sit next to ones in daily use, and a stray press ends a session
#   - the deliberate route is `power.suspend`, which cannot be hit by accident
#
# 🛑 .LockScreen is EXEMPT from that disarm, and the exemption is load-bear
#   - a lock loses no work, and costs a password
#   - so the trigger that fires for the other three does not fire here
#   - (rule.require.exemptions-name-their-trigger)
#   - 📜 2026-09-03: it WAS disarmed, no `machine.lock` existed, idle timers are off
#   - ⇒ the laptop that holds the keyrack could not be locked by any means
#
# usage:
#   rhx grove.provision --what 3.3.desktop --mode apply
######################################################################

grove_provision_3_3_desktop() {
  bundle.upgrade 3.3.desktop.configure.upsert
  bundle.upgrade 3.3.desktop.configure.verify
}
