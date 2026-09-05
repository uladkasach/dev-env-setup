#!/usr/bin/env bash
######################################################################
# .what = the tools a shell session reaches for, on every machine
#
# .why ONE bundle holds MANY package names
#         each tool here is a bare `pkg_install` name with no config of its own,
#         so a bundle per tool would be seven directories whose bodies are one
#         line each and whose headers would all say the same thing. the subject
#         of this bundle is the TOOLKIT — the set a shell session assumes.
#
#         the boundary is not "cheap to install together". it is CONFIG: the
#         moment a tool grows a file this repo writes, it earns its own bundle,
#         because that file is a second declaration and two declarations of one
#         concern is the drift shape this repo has paid for
#         (rule.require.bundle-as-sole-declaration). tmux and starship both left
#         this bundle by that rule, and their dirs are the precedent.
#
# .why tmux is NOT in this list, though it once was
#         `install_cli_deps` installed the tmux BINARY while `configure_tmux`
#         wrote its conf — one concern, two homes. so `2.8.tmux` now owns both.
#         a reader who greps for tmux finds one dir, not a package name in one
#         bundle and a heredoc in another.
#
# .why there is no CONFIGURE phase
#         no tool here is shaped by this repo. `fzf`'s keybinds do get declared —
#         but inside the zshrc that `2.5.zsh` writes, as part of that one file.
#         so this bundle is provision-only, and that absence is the declaration
#
# guarantee:
#   - identical on every machine (rule.require.identical-bundle-composition)
######################################################################

grove_provision_2_1_toolkit() {
  bundle.upgrade 2.1.toolkit.provision.upsert
  bundle.upgrade 2.1.toolkit.provision.verify
}
