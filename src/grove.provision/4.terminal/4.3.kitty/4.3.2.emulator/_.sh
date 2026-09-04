#!/usr/bin/env bash
######################################################################
# .what = the kitty terminal itself — the pinned build, and its config
#
# .why it applies to EVERY machine — and this bundle is the case that taught it
#         the old argument was "kitty is a gpu emulator, it opens a window, so a
#         headless box declines rather than install ~30MB it could never use". that
#         is wrong twice over:
#
#         1. it confuses RUN with HOLD. the tarball extracts on any linux box; only
#            `kitty` the window needs a display. and its peer `4.3.1.terminfo`
#            already proved the intuition inverts here — the box that needs the
#            `xterm-kitty` entry is the box a kitty client CONNECTS TO, which is the
#            headless one.
#
#         2. it would deny a grove `kitten`, which the tarball ships beside kitty.
#            every termwork skill in this repo drives `kitten @`, so a decline here
#            takes a capacity the grove actually uses — the very capacity kitty was
#            chosen over the flatpak build to get.
#
#         so there is NO early return, and the 30MB is worth it
#         (rule.require.identical-bundle-composition).
#
# usage:
#   rhx grove.provision --what 4.3.2.emulator --mode apply
######################################################################

grove_provision_4_3_2_emulator() {
  bundle.upgrade 4.3.2.emulator.provision.upsert
  bundle.upgrade 4.3.2.emulator.provision.verify
  bundle.upgrade 4.3.2.emulator.configure.upsert
  bundle.upgrade 4.3.2.emulator.configure.verify
}
