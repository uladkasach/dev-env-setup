#!/usr/bin/env bash
######################################################################
# .what = a virtual X display (xvfb) and a vnc bridge to it (x11vnc)
#
# .why  = some work needs an X display that no human watches: a headed
#   browser test, a gui tool driven by a command. xvfb gives the box an X
#   display in memory; x11vnc lets a human look at that display over the duct
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
