#!/usr/bin/env bash
######################################################################
# pt5: dev toolchain
# node/fnm/pnpm, claude-code/rhachet, psql, aws cli, terraform/tfenv, docker
######################################################################

install_node() {
  #########################
  ## node + npm via fnm (fast node manager)
  ## ref: https://github.com/Schniz/fnm
  #########################
  curl -fsSL https://fnm.vercel.app/install | bash -s
  source $HOME/.zshrc
  fnm install --lts
  corepack enable && corepack install -g pnpm@latest
}

install_robot_brains() {
  #########################
  ## claude-code + rhachet
  #########################
  pnpm install -g @anthropic-ai/claude-code
  pnpm install -g rhachet
}

install_psql() {
  sudo apt-get install -y postgresql-client
}

install_aws_cli() {
  ##########################
  ## ref: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  ##########################
  local tmp_dir="/tmp/aws-cli-install"
  rm -rf "$tmp_dir" && mkdir -p "$tmp_dir"
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp_dir/awscliv2.zip"
  unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir"
  sudo "$tmp_dir/aws/install"
  rm -rf "$tmp_dir"
}

install_terraform() {
  #########################
  ## terraform via tfenv
  #########################
  if [[ -d ~/.tfenv ]]; then
    echo "• tfenv already installed; skipped"
    return 0
  fi
  git clone https://github.com/tfutils/tfenv.git ~/.tfenv
  mkdir -p ~/.local/bin/
  ln -s ~/.tfenv/bin/* ~/.local/bin/

  # verify symlink created
  if [[ ! -L ~/.local/bin/tfenv ]]; then
    echo "✗ tfenv symlink not created at ~/.local/bin/tfenv"
    return 1
  fi

  # verify ~/.local/bin is in PATH (or will be after shell restart)
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    if ! grep -qE 'PATH.*\.local/bin' ~/.profile ~/.zshrc ~/.bashrc 2>/dev/null; then
      echo "✗ ~/.local/bin not in PATH; add it to ~/.profile or ~/.zshrc"
      return 1
    fi
  fi
  echo "• tfenv installed (restart shell to use)"
}

install_docker() {
  #########################
  ## docker + docker compose
  ## ref: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
  #########################

  # add Docker's official GPG key
  sudo apt-get update
  sudo apt-get install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # add the repository to apt sources
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update

  # install the packages
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # allow docker to run without root
  sudo systemctl enable --now docker
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo gpasswd -a $USER docker

  # verify the installation
  docker --version
  docker run hello-world
  docker compose version
}

clone_org_repos() {
  for organization in {ehmpathy,ahbode}; do
    gh repo list $organization --limit 1000 | while read -r repo _; do
      gh repo clone "$repo" "$HOME/git/$repo"
    done
  done
}
