#!/usr/bin/env bash
######################################################################
# .what = waypipe — a wayland app on a far box, drawn on a near screen
#
# .why  = a cloud grove has no screen. waypipe runs a gui app there and
#   paints its window on the laptop's wayland compositor, over ssh:
#     waypipe ssh <grove> <app>
#
# .why every box, both kinds — ONE binary serves both roles
#   - local grove (laptop) = the CLIENT: it holds the compositor the window lands on
#   - cloud grove          = the SERVER: it runs the app, and `waypipe ssh` starts
#     `waypipe server` there over the ssh session itself
#   - ⇒ each end needs the same package; no kind declines
#
# .why the install opens NO port
#   - waypipe rides the ssh session: a unix socket, forwarded by ssh `-R`
#   - it ships no unit and no listener, so it adds no reach to the box
#
# usage:
#   rhx grove.provision --what 5.22.waypipe --mode apply
######################################################################

grove_provision_5_22_waypipe() {
  bundle.upgrade 5.22.waypipe.provision.upsert
  bundle.upgrade 5.22.waypipe.provision.verify
}
