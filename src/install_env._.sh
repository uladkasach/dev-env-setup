#!/usr/bin/env bash
######################################################################
# dev-env-setup dispatcher
# sources each ptN file (functions only) then invokes them
######################################################################
set -euo pipefail

THIS_DIR="$HOME/git/more/dev-env-setup/src"

# temp aliases for bootstrap (lifted to bash_aliases later)
browser() { setsid flatpak run org.mozilla.firefox "$@" >/dev/null 2>&1 & }  # until install_browser_command runs
alias terminal='ptyxis 2>/dev/null || cosmic-term'
alias machine.logout='loginctl terminate-user "$USER"'
alias machine.reboot='systemctl reboot'

# pt1a: system keybinds
source "$THIS_DIR/install_env.pt1.system.keybinds.sh"
install_keyd
configure_keyd
install_keynav
configure_logind

# pt1b: system basics
source "$THIS_DIR/install_env.pt1.system.basics.sh"
install_firefox
install_browser_command
install_1password_extension
install_firefox_color_extension
install_vimium_extension
configure_firefox_prefs
configure_firefox_theme

# pt1c: system performance
source "$THIS_DIR/install_env.pt1.system.performance.sh"
configure_sysctl
configure_swapfile
install_machine_resource_procs_find_runaway
install_machine_resource_procs_find_spinner
install_machine_resource_procs_find_orphan
install_runaway_monitor
# install_earlyoom  # optional — auto-kills memory hogs before OOM freeze; see briefs/system.runaway-monitor.spec.md

# pt2: shell & git
source "$THIS_DIR/install_env.pt2.shell.sh"
install_ssh
configure_git
install_gh_cli
clone_this_repo
install_zsh
source "$THIS_DIR/install_env.pt2.shell.git.aliases.sh"
configure_git_aliases
install_cli_deps

# pt3: cosmic desktop
source "$THIS_DIR/install_env.pt3.cosmic.sh"
upgrade_cosmic_term
configure_cosmic_term
configure_cosmic_theme
configure_cosmic_desktop

# pt4: terminal & editor
source "$THIS_DIR/install_env.pt4.terminal.sh"
source "$THIS_DIR/install_env.pt4.terminal.ptyxis.sh"
source "$THIS_DIR/install_env.pt5.devtools.sh"  # sourced early for install_rust
install_fonts
install_ptyxis
configure_ptyxis
install_terminal_command
install_vim
install_rust  # must run before install_neovim (cargo needed for tree-sitter-cli)
install_neovim
configure_neovim
terminal # open a new terminal

# pt5: dev toolchain
source "$THIS_DIR/install_env.pt5.devtools.sh"
install_node
install_robot_brains
install_psql
install_aws_cli
install_terraform
install_docker
clone_org_repos

# pt6: client apps
source "$THIS_DIR/install_env.pt6.apps.sh"
install_dropbox
install_flatpak_apps
install_protonvpn
install_codium
configure_codium_copilot
configure_codium_sync

# pt7: legacy/gnome (deprecated — uncomment if needed)
# source "$THIS_DIR/install_env.pt7.legacy.sh"
# install_gnome_extensions
# configure_battery_saver
# configure_nightlight
# configure_brightness
# configure_screenshot_shortcuts
