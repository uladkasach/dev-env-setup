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
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended

  # set ZSH_CUSTOM (not set after --unattended install since shell wasn't re-sourced)
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  if [[ ! -d "$ZSH_CUSTOM" ]]; then
    echo "✗ ZSH_CUSTOM dir not found: $ZSH_CUSTOM"
    return 1
  fi

  git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" && ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
  cp ~/git/more/dev-env-setup/src/bash_aliases.sh ~/.bash_aliases
  cp ~/git/more/dev-env-setup/src/zshrc.sh ~/.zshrc
  chsh -s "$(which zsh)"
}

install_cli_deps() {
  sudo apt install -y xclip # required for pbpaste, pbcopy
  sudo apt install -y jq # required for manipulating json in terminal
  sudo apt install -y tree # required for tree view of directories
}
