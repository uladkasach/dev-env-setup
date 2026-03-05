#!/usr/bin/env bash
######################################################################
# pt4: terminal & editor
# ptyxis, terminal command, vim/neovim
######################################################################

install_ptyxis() {
  ##########################
  ## ptyxis terminal (rapid, gpu-accelerated, container-aware)
  ## ref: https://gitlab.gnome.org/chergert/ptyxis
  ## ref: https://ubuntuhandbook.org/index.php/2025/08/install-set-ptyxis-as-default-terminal-in-ubuntu-24-04-22-04/
  ## ref: https://documentation.ubuntu.com/desktop/en/latest/how-to/change-the-default-terminal/
  ##########################

  # skip if ptyxis is already the default terminal (e.g., ubuntu 25.10+, gnome 47+)
  local current_terminal
  current_terminal=$(readlink -f /usr/bin/x-terminal-emulator 2>/dev/null || echo "")
  if [[ "$current_terminal" == *ptyxis* ]]; then
    echo "• ptyxis already default terminal; skipped"
    return 0
  fi

  # install via flatpak if not already installed
  if ! flatpak list | grep -q app.devsuite.Ptyxis; then
    flatpak install -y flathub app.devsuite.Ptyxis
  fi

  # create wrapper executable for x-terminal-emulator compatibility
  sudo tee /usr/bin/ptyxis.wrapper > /dev/null << 'EOF'
#!/bin/sh
flatpak run app.devsuite.Ptyxis --new-window
EOF
  sudo chmod +x /usr/bin/ptyxis.wrapper

  # register and set as default terminal (ctrl+alt+t)
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ptyxis.wrapper 50
  sudo update-alternatives --set x-terminal-emulator /usr/bin/ptyxis.wrapper
}

# note: configure_ptyxis is defined in install_env.pt4.terminal.ptyxis.sh, sourced by dispatcher

install_terminal_command() {
  # .what = install 'terminal' command that opens terminal at specified directory
  # .why  = 'terminal .' works in scripts, subshells, git tree, etc (unlike alias)
  # .note = setsid -f starts new session so child terminal survives parent close
  sudo tee /usr/bin/terminal > /dev/null << 'EOF'
#!/usr/bin/env bash
dir="${1:-.}"
dir="$(realpath "$dir")"
setsid -f flatpak run app.devsuite.Ptyxis --new-window --working-directory "$dir"
EOF
  sudo chmod +x /usr/bin/terminal
}

install_vim() {
  sudo apt install vim -y
}

install_neovim() {
  sudo add-apt-repository ppa:neovim-ppa/unstable -y && sudo apt update && sudo apt install neovim -y
}

configure_neovim() {
  mkdir -p ~/.config/nvim
  cp "$HOME/git/more/dev-env-setup/src/init.lua" ~/.config/nvim/init.lua
  echo "• neovim config applied"
}
