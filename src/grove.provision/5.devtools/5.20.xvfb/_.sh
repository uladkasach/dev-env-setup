#!/usr/bin/env bash
######################################################################
# .what = a virtual X display (xvfb) and a vnc bridge to it (x11vnc)
#
# .why  = some work needs an X display that no human watches: a headed
#   browser test, a gui tool driven by a command. xvfb gives the box an X
#   display in memory; x11vnc lets a human look at that display over the duct;
#   xdotool presses real keys into it (`rhx kitty.sandbox press`)
#
# .why keys go into a virtual display, never the human's session
#   - a key a terminal maps (kitty.conf `map …`) is only matched on a real
#     key event, so a test of the map must press one
#   - a press into the human's session (keyd's virtual keyboard, ydotool)
#     lets any process as this user type into the focused window — a cached
#     sudo prompt included. that is a privilege no test needs
#   - XTEST into a private Xvfb reaches only that display; any process as
#     this user could already start one, so the press grants naught new
#
# .why every box, the laptop included
#   - a cloud grove has no screen at all
#   - a laptop has one, but a headless run there must not paint over the
#     human's own screen, so it wants a separate, virtual display too
#
# .why the install opens NO port
#   - x11vnc serves a screen over the network, so a listener is the hazard
#     (the `2.3.ssh` precedent: a package that listens at install time)
#   - debian's x11vnc ships no enabled unit; the verify PROVES no x11vnc
#     process or unit runs, so a future package change that adds one reddens
#   - a human starts it per need, bound to localhost, and reaches it via ssh -L
#
# usage:
#   rhx grove.provision --what 5.20.xvfb --mode apply
######################################################################

grove_provision_5_20_xvfb() {
  bundle.upgrade 5.20.xvfb.provision.upsert
  bundle.upgrade 5.20.xvfb.provision.verify
}
