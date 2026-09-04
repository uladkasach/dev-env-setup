#!/usr/bin/env bash
######################################################################
# .what = neovim — the pinned binary, its parser compiler, and its config
#
#   - ONE bundle: split in two, neither half could state a claim about the other
#
# .it applies EVERYWHERE, grove included
#   - nvim runs ON the grove, so the grove needs the binary, parsers, and config
#   - ⚠️ imagemagick LOOKS local-only and is not
#   - an inline image is CONVERTED where nvim runs, and emits kitty graphics escapes
#   - those travel back over tmux `allow-passthrough` and ssh to the LOCAL kitty
#
# ⚠️ .this bundle installs NO tree-sitter-cli, though nvim needs it
#   - the crate needs cargo, and cargo arrives with `5.2.rust` in a later section
#   - a FIRST apply could never build it, and would tell a human to apply twice
#   - rust cannot move here, since a toolchain is no editor's child
#   - ⇒ the CONSUMER sits at `5.14.treesitter`, behind `5.2.rust`
#
# usage:
#   rhx grove.provision --what 4.5.nvim --mode apply
######################################################################

grove_provision_4_5_nvim() {
  bundle.upgrade 4.5.nvim.provision.upsert
  bundle.upgrade 4.5.nvim.provision.verify
  bundle.upgrade 4.5.nvim.configure.upsert
  bundle.upgrade 4.5.nvim.configure.verify
}
