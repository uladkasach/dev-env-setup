#!/usr/bin/env bash
######################################################################
# .what = the `terminal` command — open a kitty window at a given directory
#
# .why  it is a CHILD of 4.3.kitty rather than a peer
#         its body is literally `kitty --directory`. the name is generic; the
#         coupling is not, and a bundle should sit where its dependency is
#         (rule.require.bundle-names-name-their-subject). were the emulator ever
#         swapped, this moves with it — which is exactly the relation the tree
#         should record.
#
# .why  a command on PATH and not a shell alias
#         an alias exists only in an interactive shell that sourced it. `terminal .`
#         is reached from a procedure file, a subshell, a git hook, and a file
#         manager's "open here" action — none of which read `.bash_aliases`. only
#         a real executable serves all four.
#
# .why  it applies ONLY where a screen exists
#         it opens a WINDOW. its parent 4.3.2.emulator deliberately does NOT
#         decline — the tarball ships `kitten`, which a grove uses — but no
#         headless box can act on a launcher, so this child declines where its
#         parent does not. that split is the reason it is its own bundle.
#
# usage:
#   rhx grove.provision --what 4.3.3.launcher --mode apply
######################################################################

grove_provision_4_3_3_launcher() {
  bundle.upgrade 4.3.3.launcher.provision.upsert
  bundle.upgrade 4.3.3.launcher.provision.verify
}
