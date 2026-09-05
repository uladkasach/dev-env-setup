#!/usr/bin/env bash
######################################################################
# .what = the COSMIC desktop — its terminal, its theme, and its shell layout
#
# .every child declines on a cloud box
#   - COSMIC is a wayland compositor, and a grove runs none
#   - so every file this section writes would be read by no process
#   - the gate lives in each LEAF, since a parent gate takes the claim from its owner
#
# ⚠️ .the theme paths read `$GROVE_SRC`
#   - a hardcoded `$HOME/git/more/dev-env-setup/src/...` names MAIN
#   - from a worktree that themes a desktop from a different commit than its terminal
#   - (howto.install-configs-from-a-worktree)
#
# .order
#   - `3.1.term` goes first, since `3.3.desktop` points COSMIC's Terminal action at it
#
# usage:
#   rhx grove.provision --what 3.cosmic --mode apply
######################################################################

grove_provision_3_cosmic() {
  bundle.upgrade 3.1.term
  bundle.upgrade 3.2.theme
  bundle.upgrade 3.3.desktop
}
