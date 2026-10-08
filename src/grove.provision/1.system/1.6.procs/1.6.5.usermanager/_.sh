#!/usr/bin/env bash
######################################################################
# .what = the user's systemd manager comes back when it dies
#
# .why  it is its own leaf beside `1.6.3.earlyoom`
#   earlyoom decides WHO dies under pressure; this decides what happens AFTER a
#   death that hit the session itself. they fail apart: a bad victim policy
#   kills the bus, and an absent revive leaves it dead until a re-login. each
#   wants its own repair, which is the split test
#   (rule.require.bundle-names-name-their-subject)
#
# .why it applies to every box class
#   a cloud grove's seats run `systemd-run --user` too (the `claude` wrapper),
#   and a headless seat has no human to re-login at all
#
# usage:
#   sudo -v && rhx grove.provision --what 1.6.5.usermanager --mode apply
######################################################################

# the one declaration of where the drop-in lands, shared by both halves
GROVE_USERMANAGER_DROPIN="/etc/systemd/system/user@.service.d/10-revive.conf"

grove_provision_1_6_5_usermanager() {
  bundle.upgrade 1.6.5.usermanager.configure.upsert
  bundle.upgrade 1.6.5.usermanager.configure.verify
}
