#!/usr/bin/env bash
######################################################################
# .what = never suspend, never hibernate, never idle-lock — at the systemd layer
#
# .why
#   - a suspend mid-work costs every unsaved buffer, ssh session, and duct this repo opened
#   - every trigger is accidental: a power key by the arrows, a lid, a display unplug, an idle timer
#   - ref: .agent/repo=.this/role=any/briefs/desktop/system/system.power.spec.md
#
# .why it holds NO provision phase
#   - `logind` ships with systemd, which every box this repo supports already has
#   - the whole concern is a declaration, so the bundle has a configure pair and no other
#   - a phase list is what a bundle HAS, never a template it must fill
#
# .why it applies to EVERY box, headless included
#   - logind is present on a grove too
#   - an idle ec2 box that locks or suspends drops every duct and ssh session this repo opened
#   - ⇒ `IdleAction=ignore` is exactly as wanted there
#   - a lid switch that does not exist costs one ignored key in a config file
#   - so there is NO early return (rule.require.identical-bundle-composition)
#
# .note = HIBERNATION is a BOUNDARY here, not an omission
#   - an aws grove registers its own hibernation swap target, which is the image's business
#   - (rule.require.bounded-contexts)
#
# .the two layers with 1.1.keybinds
#   - `1.1.keybinds` sets the power/sleep/suspend keys to `noop` at the DEVICE layer
#   - this sets logind to ignore them at the SYSTEM layer
#   - the device layer catches a key before logind ever sees it
#   - the system layer catches every OTHER path: the lid, an idle timer, a desktop menu item
#
# usage:
#   rhx grove.provision --what 1.2.power --mode apply
######################################################################

grove_provision_1_2_power() {
  bundle.upgrade 1.2.power.configure.upsert
  bundle.upgrade 1.2.power.configure.verify
}
