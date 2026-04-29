#!/usr/bin/env bash
######################################################################
# pt5: dev toolchain
# node/fnm/pnpm, claude-code/rhachet, psql, usql, aws cli, terraform/tfenv, docker
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

install_rust() {
  #########################
  ## rust via rustup
  ## ref: https://rustup.rs/
  #########################
  sudo apt install -y libclang-dev  # required for cargo bindgen (e.g., tree-sitter-cli)
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
}

install_robot_brains() {
  #########################
  ## claude-code + rhachet
  #########################
  pnpm install -g @anthropic-ai/claude-code
  pnpm install -g rhachet
}

install_ripgrep() {
  #########################
  ## ripgrep - fast grep alternative
  ## used by: telescope.nvim live_grep
  #########################
  sudo apt install -y ripgrep
}

install_psql() {
  sudo apt-get install -y postgresql-client
}

install_usql() {
  #########################
  ## usql: universal CLI for 40+ databases (postgres, duckdb, athena, etc)
  ## ref: https://github.com/xo/usql
  #########################
  local version="0.19.14"
  local tmp_dir="/tmp/usql-install"
  local archive="usql_static-${version}-linux-amd64.tar.bz2"
  local url="https://github.com/xo/usql/releases/download/v${version}/${archive}"

  rm -rf "$tmp_dir" && mkdir -p "$tmp_dir"
  curl -fsSL "$url" -o "$tmp_dir/$archive"
  tar -xjf "$tmp_dir/$archive" -C "$tmp_dir"

  mkdir -p ~/.local/bin
  mv "$tmp_dir/usql_static" ~/.local/bin/usql
  chmod +x ~/.local/bin/usql
  rm -rf "$tmp_dir"

  echo "• usql installed to ~/.local/bin/usql"
  usql --version
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

install_aws_ssm() {
  #########################
  ## aws ssm session manager plugin
  ## required for: aws ssm start-session, rds port forwarding, etc.
  ## ref: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
  #########################
  if command -v session-manager-plugin &>/dev/null; then
    echo "• ssm plugin already installed; skipped"
    return 0
  fi
  local tmp_deb="/tmp/session-manager-plugin.deb"
  curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "$tmp_deb"
  sudo dpkg -i "$tmp_deb"
  rm -f "$tmp_deb"
  session-manager-plugin --version
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
  echo "• docker group added. to use docker without logout, run: newgrp docker && exec zsh -l && zsh"

  # verify the installation
  docker --version
  docker run hello-world
  docker compose version
}

install_1password() {
  #########################
  ## ref: https://support.1password.com/install-linux/
  #########################

  # findsert apt repo
  [ -f /usr/share/keyrings/1password-archive-keyring.gpg ] || \
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
      sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  [ -f /etc/apt/sources.list.d/1password.list ] || \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
      sudo tee /etc/apt/sources.list.d/1password.list

  # findsert app
  command -v 1password &> /dev/null || \
    (sudo apt update && sudo apt install -y 1password)

  # findsert cli
  command -v op &> /dev/null || \
    (sudo apt update && sudo apt install -y 1password-cli && op --version)

  # upsert auto-lock timer (cosmic desktop doesn't support native idle detection)
  # ref: https://1password.community/discussion/121078
  mkdir -p ~/.config/systemd/user

  cat > ~/.config/systemd/user/1password-lock.service << 'EOF'
[Unit]
Description=Lock 1Password

[Service]
Type=oneshot
ExecStart=/usr/bin/1password --lock
EOF

  cat > ~/.config/systemd/user/1password-lock.timer << 'EOF'
[Unit]
Description=Lock 1Password every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now 1password-lock.timer

  echo "configure 1password app manually:"
  echo "  1. settings > developer > enable 'integrate with 1password cli'"
}

install_yubikey_agent() {
  #########################
  ## yubikey-agent: seamless ssh-agent backed by YubiKey PIV
  ## ref: https://github.com/FiloSottile/yubikey-agent
  ## author: Filippo Valsorda (Go crypto maintainer, ex-Google Security)
  #########################

  # findsert yubikey-agent + ykman
  command -v yubikey-agent &> /dev/null || sudo apt install -y yubikey-agent
  command -v ykman &> /dev/null || sudo apt install -y yubikey-manager

  # enable systemd services (apt package provides service file)
  systemctl --user daemon-reload
  systemctl --user enable --now pcscd.socket
  systemctl --user enable --now yubikey-agent.service

  # add SSH_AUTH_SOCK to bash_aliases if not present
  if ! grep -q "yubikey-agent" ~/git/more/dev-env-setup/src/bash_aliases.sh 2>/dev/null; then
    echo "" >> ~/git/more/dev-env-setup/src/bash_aliases.sh
    echo "# yubikey-agent ssh socket" >> ~/git/more/dev-env-setup/src/bash_aliases.sh
    echo 'export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock"' >> ~/git/more/dev-env-setup/src/bash_aliases.sh
  fi

  echo ""
  echo "yubikey-agent installed."
  echo ""
  echo "next steps:"
  echo "  1. sync.devenv.bashaliases  # apply SSH_AUTH_SOCK"
  echo ""
  echo "to load key onto yubikey (first time or new yubikey):"
  echo "  source ~/git/more/dev-env-setup/src/util.yubikey.ssh.sh"
  echo "  openssl ecparam -name prime256v1 -genkey -noout -out ~/.ssh/yubikey.pem"
  echo "  set_sshkey_into_yubikey --from ~/.ssh/yubikey.pem --name my-ssh-key"
  echo ""
  echo "to load same key onto another yubikey (from 1password backup):"
  echo "  set_sshkey_into_yubikey --from 'op://Private/my-ssh-key'"
  echo ""
  echo "to get public key (new machine setup):"
  echo "  get_sshkey_from_yubikey                          # print pubkey"
  echo "  get_sshkey_from_yubikey --into ~/.ssh            # write to ~/.ssh/yubikey.pub"
  echo "  get_sshkey_from_yubikey --into ~/.ssh --name work  # write to ~/.ssh/work.pub"
}

clone_org_repos() {
  for organization in {ehmpathy,ahbode}; do
    gh repo list $organization --limit 1000 | while read -r repo _; do
      gh repo clone "$repo" "$HOME/git/$repo"
    done
  done
}
