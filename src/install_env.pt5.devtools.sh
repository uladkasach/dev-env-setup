#!/usr/bin/env bash
######################################################################
# pt5: dev toolchain
# node/fnm/pnpm, psql, aws cli, terraform/tfenv, docker
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

install_psql() {
  sudo apt-get install -y postgresql-client
}

install_aws_cli() {
  ##########################
  ## ref: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  ##########################
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
}

install_terraform() {
  #########################
  ## terraform via tfenv
  #########################
  git clone https://github.com/tfutils/tfenv.git ~/.tfenv
  mkdir -p ~/.local/bin/
  . ~/.profile
  ln -s ~/.tfenv/bin/* ~/.local/bin
  . ~/.profile
  which tfenv
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

######################################################################
# run
######################################################################
install_node
install_psql
install_aws_cli
install_terraform
install_docker
clone_org_repos
