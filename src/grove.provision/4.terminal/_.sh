#!/usr/bin/env bash
######################################################################
# .what = the terminal & editor section — the emulators, the fonts, the editor
#
#   - it holds no predicate: kitty needs a screen and its terminfo entry does not
#   - only those two bundles know that, so neither answer belongs here
#
# .order
#   - `4.1.fonts` runs FIRST, since kitty asks fontconfig for that font BY NAME
#   - run second, kitty would open once and draw tofu (▯) for every icon
#   - `4.4.vim` runs before `4.5.nvim`, since vim is what repairs a broken nvim
#   - `4.6.pqiv` has no dependency on the rest of this section, so its slot last
#
# 🛑 .there is no `4.2` — ptyxis was a second emulator, kept as a fallback
#   - 📜 it cost a flatpak, a flathub remote, a root wrapper, and four phases
#   - 📜 every one reached for root on a converged box, on every apply
#   - ⇒ the numbers are NOT re-flowed to close the gap
#   - a slug is a NAME, and a rename breaks every reference for a run of digits
#   - (rule.require.bundle-slug-matches-its-path)
#
# usage:
#   rhx grove.provision --what 4.terminal --mode apply
######################################################################

grove_provision_4_terminal() {
  bundle.upgrade 4.1.fonts
  bundle.upgrade 4.3.kitty
  bundle.upgrade 4.4.vim
  bundle.upgrade 4.5.nvim
  bundle.upgrade 4.6.pqiv
}
