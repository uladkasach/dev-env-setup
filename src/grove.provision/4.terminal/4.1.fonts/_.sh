#!/usr/bin/env bash
######################################################################
# .what = the two fonts a terminal draws code with — FiraCode and Hack Nerd Font
#
# .why  it applies ONLY where a screen exists — and this is the MIRROR of 4.3.1
#         `4.3.1.terminfo` proved that a terminal concern can belong on the box a
#         client CONNECTS TO rather than the box a human sits at. a font is the
#         same axis with the OPPOSITE answer, and that symmetry is why this note
#         exists:
#
#           terminfo   describes what the REMOTE program may emit  → remote box
#           font       rasterizes what the LOCAL window draws      → local box
#
#         a grove renders not one glyph. its nvim, its tmux, its ncurses tools all
#         emit BYTES; the pixels are drawn by the kitty window on the laptop. so a
#         Hack Nerd Font installed on a grove has no consumer at all — no process
#         there ever opens it.
#
#         so the rule.require.identical-bundle-composition exception is genuinely
#         earned here: this is not "the cloud box could use it but it's big", it is
#         "the cloud box has no font client in the first place".
#
# .why  the icons matter, not just the ligatures
#         neo-tree, lualine, and gitsigns draw from the nerd-font private-use
#         range. absent the font those code points fall back to tofu (▯), so the
#         file tree reads as a column of empty boxes — a defect that looks like a
#         plugin bug and is not.
#
# usage:
#   rhx grove.provision --what 4.1.fonts --mode apply
######################################################################

grove_provision_4_1_fonts() {
  bundle.upgrade 4.1.fonts.provision.upsert
  bundle.upgrade 4.1.fonts.provision.verify
  bundle.upgrade 4.1.fonts.configure.upsert
  bundle.upgrade 4.1.fonts.configure.verify
}
