#!/usr/bin/env bash
######################################################################
# dev-env-setup dispatcher
# runs each ptN file which defines functions and invokes them
######################################################################
set -euo pipefail

THIS_DIR="$HOME/git/more/dev-env-setup/src"

# temp aliases used during install (lifted to bash_aliases later)
alias browser='flatpak run org.mozilla.firefox'
alias terminal='ptyxis 2>/dev/null || cosmic-term'
alias machine.logout='loginctl terminate-user "$USER"'
alias machine.reboot='systemctl reboot'

bash "$THIS_DIR/install_env.pt1.system.keybinds.sh"
bash "$THIS_DIR/install_env.pt1.system.performance.sh"
bash "$THIS_DIR/install_env.pt2.shell.sh"
bash "$THIS_DIR/install_env.pt3.cosmic.sh"
bash "$THIS_DIR/install_env.pt4.terminal.sh"
terminal # open a new terminal
bash "$THIS_DIR/install_env.pt5.devtools.sh"
bash "$THIS_DIR/install_env.pt6.apps.sh"
# bash "$THIS_DIR/install_env.pt7.legacy.sh"  # deprecated
