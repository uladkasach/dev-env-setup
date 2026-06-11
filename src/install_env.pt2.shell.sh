#!/usr/bin/env bash
######################################################################
# pt2: shell & git
# ssh, git config, gh cli, clone repo, zsh, bash_aliases, git aliases, cli deps
######################################################################

install_ssh() {
  sudo apt-get install ssh -y
  ssh-keygen # use the default path to save the key; create your own password
}

configure_git() {
  # require GIT_USER_EMAIL and GIT_USER_NAME (prompt if not set)
  if [[ -z "${GIT_USER_EMAIL:-}" ]]; then
    read -rp "git user.email (e.g., jane.doe@gmail.com): " GIT_USER_EMAIL
  fi
  if [[ -z "${GIT_USER_NAME:-}" ]]; then
    read -rp "git user.name (e.g., Jane Doe): " GIT_USER_NAME
  fi
  if [[ -z "$GIT_USER_EMAIL" || -z "$GIT_USER_NAME" ]]; then
    echo "✗ GIT_USER_EMAIL and GIT_USER_NAME required"
    return 1
  fi

  git config --global user.email "$GIT_USER_EMAIL"
  git config --global user.name "$GIT_USER_NAME"
  git config --global pull.ff only
  git config --global init.defaultBranch main
}

install_gh_cli() {
  ########################
  ## ref: https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt
  ########################
  type -p curl >/dev/null || sudo apt install curl -y
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
  gh auth login
}

clone_this_repo() {
  mkdir -p ~/git/more
  git clone git@github.com:uladkasach/dev-env-setup.git ~/git/more/dev-env-setup
}

install_zsh() {
  sudo apt install zsh

  cp ~/git/more/dev-env-setup/src/bash_aliases.sh ~/.bash_aliases
  cp ~/git/more/dev-env-setup/src/ductwork.sh ~/.bash_aliases.ductwork.sh
  cp ~/git/more/dev-env-setup/src/zshrc.sh ~/.zshrc
  chsh -s "$(which zsh)"
}

install_cli_deps() {
  sudo apt install -y xclip # required for pbpaste, pbcopy
  sudo apt install -y jq # required for json in terminal
  sudo apt install -y tree # required for tree view of directories
  sudo apt install -y fzf # fuzzy finder for history, files, etc
  sudo apt install -y tmux # required for ductwork (headless terminal streams)
}

configure_tmux() {
  mkdir -p ~/.config/tmux
  cp ~/git/more/dev-env-setup/src/tmux.conf ~/.config/tmux/tmux.conf
}

install_starship() {
  #########################
  ## starship: cross-shell prompt in rust
  ## ref: https://starship.rs/
  #########################
  local version="1.24.2"
  local archive="starship-x86_64-unknown-linux-musl.tar.gz"
  local url="https://github.com/starship/starship/releases/download/v${version}/${archive}"
  local tmp_dir="/tmp/starship-install"

  rm -rf "$tmp_dir" && mkdir -p "$tmp_dir"
  curl -fsSL "$url" -o "$tmp_dir/$archive"
  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"

  mkdir -p ~/.local/bin
  mv "$tmp_dir/starship" ~/.local/bin/starship
  chmod +x ~/.local/bin/starship
  rm -rf "$tmp_dir"

  mkdir -p ~/.config
  cp ~/git/more/dev-env-setup/src/starship.toml ~/.config/starship.toml

  echo "• starship v${version} installed to ~/.local/bin/starship"
  starship --version
}
