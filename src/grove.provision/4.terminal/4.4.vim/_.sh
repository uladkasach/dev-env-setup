#!/usr/bin/env bash
######################################################################
# .what = vim — the editor of last resort, kept beside nvim on purpose
#
# .why  vim AND nvim, when 4.5.nvim is the editor in daily use
#         nvim here is a PINNED TARBALL under /opt with a config that loads ~40
#         plugins. every part of that can break: a bad pin, a half-extracted
#         tarball, a lua error in init.lua. and what a human reaches for to repair
#         a broken editor is an editor.
#
#         vim is debian's, apt-managed, config-free, and has no shared failure
#         mode with the tarball. so it is the one editor that survives whatever
#         breaks nvim — which is the entire reason it is declared.
#
# .why  it applies to EVERY machine
#         a grove is repaired through a duct, and a duct is a shell. so the box
#         that most needs an editor that starts after a bad nvim upgrade is the
#         REMOTE one, where there is no second window to open. no decline here.
#
# .why  it holds no `configure` phase
#         a configured vim would share a failure mode with nvim — a config that
#         can break. vim's value is that it is the UNCONFIGURED fallback.
#
# usage:
#   rhx grove.provision --what 4.4.vim --mode apply
######################################################################

grove_provision_4_4_vim() {
  bundle.upgrade 4.4.vim.provision.upsert
  bundle.upgrade 4.4.vim.provision.verify
}
