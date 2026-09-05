#!/usr/bin/env bash
######################################################################
# .what = pqiv — the vim-navigable image viewer `nimg` invokes
#
# .why it applies to EVERY box, headless included — the pqiv install needs no
#   display, only its CONFIG needs one, and even that write is plain files
#   (rule.require.identical-bundle-composition, the firefox/1.3.1 precedent:
#   "a gui browser needs a display" is true of RUNNING it and false of
#   HOLDING the bundle)
#
# .why it holds a configure phase at all
#   pqiv's vim-style keybinds (h/j/k/l pan, gg/G jump, ctrl+j/k zoom) are not
#   its defaults — `~/.config/pqivrc` is what turns it into the tool `nimg`
#   promises. an install with no config is a plain apt package with none of
#   the reason this bundle exists.
#
# usage:
#   rhx grove.provision --what 4.6.pqiv --mode apply
######################################################################

grove_provision_4_6_pqiv() {
  bundle.upgrade 4.6.pqiv.provision.upsert
  bundle.upgrade 4.6.pqiv.provision.verify
  bundle.upgrade 4.6.pqiv.configure.upsert
  bundle.upgrade 4.6.pqiv.configure.verify
}
