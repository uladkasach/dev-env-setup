#!/usr/bin/env bash
######################################################################
# .what = tree-sitter-cli — the compiler nvim-treesitter builds parsers with
#
# .why it is a bundle of its own, and dispatched at `5.14`
#   - its build needs cargo (from `5.2.rust`), unavailable inside `4.5.nvim`,
#     where section 5 runs after section 4
#   - `5.3` is taken, so it takes the free tail number; the dispatch list, not
#     the digits, places it right after rust
#   - .refs = howdoes.5-devtools-dispatch-order.md
#
# .why it applies everywhere, headless included
#   - a grove reads code through nvim over a duct; with no parser compiler,
#     every treesitter feature — syntax, folds, codediff — stays off
#
# usage:
#   rhx grove.provision --what 5.14.treesitter --mode apply
######################################################################

####################################################################
# the tree-sitter-cli pin — ONE declaration, read by BOTH halves
#
# .why here, and why pinned, and what the pin leaves open
#   - the upsert installs against it, the verify compares the live binary
#     against it (`gotcha.a-check-that-cries-wolf`, m.9 / m.13)
#   - a third-party crate compiled and RUN on this box makes an unreviewed
#     publish arbitrary code, as this human (`5.3.brains/_.sh`, same split)
#   - `cargo install` ignores the crate's own lockfile without `--locked`, so
#     every TRANSITIVE dependency still resolves fresh — `--locked` fails the
#     install on a crate with no lockfile, so it stays unproven and unshipped
#   - .refs = howdoes.5-14-treesitter-pin.md
#
# .how to bump
#   - read what the box RUNS, decide, put it here, apply the bundle:
#       tree-sitter --version
####################################################################
GROVE_TREESITTER_PIN="0.26.10"

grove_provision_5_14_treesitter() {
  bundle.upgrade 5.14.treesitter.provision.upsert
  bundle.upgrade 5.14.treesitter.provision.verify
}
