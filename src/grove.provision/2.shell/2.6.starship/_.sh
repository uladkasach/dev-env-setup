#!/usr/bin/env bash
######################################################################
# .what = the starship prompt — the binary, and the prompt config it reads
#
# .why  = one bundle rather than two. `install_starship` and `configure_starship`
#         were two inventory members, split apart on 2026-07-27 so a config
#         refresh would not re-download a binary. that split was right about the
#         ACT and wrong about the UNIT: they are one concern with four phases.
#
# .why it applies everywhere
#         a prompt is the shell's, and a grove's shell is reached over ssh, so it
#         needs its prompt as much as a laptop does. no part of starship depends
#         on a screen, a human, or a display — so there is no predicate to ask
#
# usage:
#   rhx grove.provision --what 2.6.starship --mode apply
######################################################################

grove_provision_2_6_starship() {
  bundle.upgrade 2.6.starship.provision.upsert
  bundle.upgrade 2.6.starship.provision.verify
  bundle.upgrade 2.6.starship.configure.upsert
  bundle.upgrade 2.6.starship.configure.verify
}
