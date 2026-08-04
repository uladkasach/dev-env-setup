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

  local src_dir="${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}/src"
  cp "$src_dir/bash_aliases.sh" ~/.bash_aliases
  cp "$src_dir/ductwork.sh" ~/.bash_aliases.ductwork.sh
  cp "$src_dir/termwork.sh" ~/.bash_aliases.termwork.sh
  cp "$src_dir/zshrc.sh" ~/.zshrc
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
  local src_dir="${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}/src"

  cp "$src_dir/tmux.conf" ~/.tmux.conf
  echo "• tmux.conf installed"

  # install tpm (tmux plugin manager) if not present
  if [[ ! -d ~/.tmux/plugins/tpm ]]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    echo "• tpm installed"
  fi

  # install plugins via tpm (headless)
  # run install inside tmux so tpm can read its own config
  tmux new-session -d -s _tpm_init
  tmux run-shell -t _tpm_init ~/.tmux/plugins/tpm/bin/install_plugins
  tmux kill-session -t _tpm_init 2>/dev/null || true
  echo "• tmux plugins installed"
}

install_emoji() {
  #########################
  ## emoji: inline emoji autocomplete in zsh
  ## ':turt<TAB>' -> 🐢   ':zap:' -> ⚡   ':zap<Enter>' -> emoji zap
  ##
  ## two artifacts:
  ##   ~/.zshrc.emoji.sh  the zle widget + `emoji` command (sourced by zshrc)
  ##   ~/.local/share/emoji/emoji.tsv  the index (built from CLDR + unicode)
  ##
  ## .note = zsh only. it uses zle/bindkey, so it must NOT go in
  ##         ~/.bash_aliases — BASH_ENV makes bash source that file, and
  ##         bash has no zle. zshrc.sh sources it after compinit + fzf.
  #########################
  local src_dir="${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}/src"

  # fzf powers the picker on ambiguous matches; jq builds the index.
  # both come from install_cli_deps, which runs immediately before this
  # in install_env._.sh — so assert rather than re-apt. a second
  # `apt install` here would duplicate that fn and, worse, prompt for a
  # sudo password mid-install for packages already present.
  local absent=()
  command -v fzf >/dev/null || absent+=(fzf)
  command -v jq  >/dev/null || absent+=(jq)
  if (( ${#absent[@]} )); then
    echo "✋ emoji needs: ${absent[*]}" >&2
    echo "   run install_cli_deps first (install_env._.sh orders it before this)" >&2
    return 2
  fi

  cp "$src_dir/emoji.zsh" ~/.zshrc.emoji.sh
  echo "• emoji widget installed"

  # build the index. this is the same file `rhx emoji.index.set` runs,
  # so the human and the agent can never drift apart.
  bash "$src_dir/emoji.index.build.sh"

  # prove it works before we claim it does. the suite rebinds no keys —
  # it stubs zle and drives the widgets headlessly, so it is safe here.
  zsh "$src_dir/emoji.test.zsh" || {
    echo "✋ emoji widget failed its own tests — install is not sound" >&2
    return 1
  }
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

  local src_dir="${DEV_ENV_SETUP_DIR:-$HOME/git/more/dev-env-setup}/src"
  mkdir -p ~/.config
  cp "$src_dir/starship.toml" ~/.config/starship.toml

  echo "• starship v${version} installed to ~/.local/bin/starship"
  starship --version
}
