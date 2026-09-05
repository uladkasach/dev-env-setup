#!/usr/bin/env bash
######################################################################
# .what = the rust toolchain — rustup, cargo, and the C linker cargo needs
#
# .why  it is a devtool, and its one consumer is its NEIGHBOUR
#         `5.14.treesitter` builds `tree-sitter-cli` with cargo, and it is
#         dispatched immediately after this bundle for exactly that reason.
#
# 📜 .the two homes that consumer has had
#         the old roll encoded the bond as ORDER: an `install_rust` line above
#         `install_neovim`, with a comment that said "must precede". a sequence a
#         reader must infer from a comment in another file is not a dependency
#         the machine can honor; reorder the lines and it silently breaks.
#
#         so it became an explicit CLAIM instead — `4.5.nvim`'s provision tested
#         for cargo and named `--what 5.devtools` as its fix. that was better and
#         still wrong, because section 4 runs BEFORE section 5: the claim was
#         honest and unsatisfiable on a first apply, so the phase declined with a
#         🌙 that told a human to apply twice.
#
#         ⇒ 2026-08-12: the consumer moved to `5.14.treesitter`, right behind
#           this bundle. a dependency is now expressed as ADJACENCY in the
#           dispatcher, which needs no comment, no cross-section claim, and no
#           second apply (`rule.require.one-command-provision`).
#
# .why  it applies to EVERY machine
#         a grove compiles tree-sitter parsers exactly as a laptop does — a grove
#         reads code through nvim over a duct, and with no parser compiler every
#         treesitter feature stays off. no decline.
#
# usage:
#   rhx grove.provision --what 5.2.rust --mode apply
######################################################################

grove_provision_5_2_rust() {
  bundle.upgrade 5.2.rust.provision.upsert
  bundle.upgrade 5.2.rust.provision.verify
}
