#!/usr/bin/env bash
######################################################################
# .what = kitty — the terminal, the terminfo entry a client needs, its launcher,
#         and the session snapshot
#
# .why four children, not one — they differ in WHERE they apply
#   - `4.3.1.terminfo` — the `xterm-kitty` entry, EVERY machine: the box
#     that needs it is the one a kitty client CONNECTS TO, usually remote
#     (.refs = gotcha.4-3-kitty.demo=absent-terminfo-three-symptoms.md)
#   - `4.3.2.emulator` — the gpu terminal, ALSO every machine, since its
#     tarball ships `kitten`, which a grove drives too
#   - `4.3.3.launcher` — the `terminal` command, only where a screen
#     exists, since a launcher with no window has none to open
#   - `4.3.4.snapshot` — the low-battery session snap, also screen-only,
#     since it captures WINDOWS and a grove's battery is a fiction
#   - the four answers split 2-and-2 by NEITHER-declines vs cloud-declines,
#     so a single flat applicability, or two unrelated top-level bundles,
#     would each lose part of this relation — this body holds no predicate
#
# .order
#   - terminfo first: where a screen exists, the emulator's tarball also
#     ships the entry, so terminfo-first finds that claim already satisfied
#   - snapshot LAST: its guard reads a kitty process tree, so it is the
#     one child whose subject must already be on the box
#
# usage:
#   rhx grove.provision --what 4.3.kitty --mode apply
######################################################################

grove_provision_4_3_kitty() {
  bundle.upgrade 4.3.1.terminfo
  bundle.upgrade 4.3.2.emulator
  bundle.upgrade 4.3.3.launcher
  bundle.upgrade 4.3.4.snapshot
}
