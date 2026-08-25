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

# the claude-code version this env holds at.
# .why = claude truncates hook output beyond v2.1.87, and our hooks (permission
#   checks, role boot, route drive) depend on that output being whole. so we pin
#   deliberately instead of tracking latest (rule.require.pinned-versions).
# .note = raise this only after verifying hook output survives the new version
CLAUDE_CODE_VERSION_PINNED='2.1.87'

install_robot_brains() {
  #########################
  ## claude-code + rhachet + codex
  ## ref: https://github.com/anthropics/claude-code
  ## ref: https://github.com/openai/codex
  #########################
  pnpm install -g rhachet
  pnpm install -g @openai/codex

  # note: claude-code itself is installed by configure_robot_brains, so that the
  # pin + shadow prune converge on every `sync.devenv.brains`, not just on install
  configure_robot_brains
}

prune_claude_code_shadows() {
  #########################
  ## remove npm-global claude-code installs that outrank the pinned pnpm copy
  #########################

  # .what = uninstall @anthropic-ai/claude-code from every fnm node version
  # .why = `fnm env --use-on-cd` puts fnm's multishell bin ahead of PNPM_HOME on
  #   every shell, and the PNPM_HOME prepend in zshrc is skipped when PNPM_HOME is
  #   already anywhere in PATH. so a stray `npm install -g @anthropic-ai/claude-code`
  #   (or claude's own native-installer migration) silently outranks the pinned
  #   pnpm copy — and since no alias or pin binds claude, the swap goes unnoticed.
  #   a prune at the source is the only guard PATH order cannot undo.
  local pruned=0
  local nodedir

  for nodedir in "$HOME"/.local/share/fnm/node-versions/*/installation; do
    [[ -d "$nodedir/lib/node_modules/@anthropic-ai/claude-code" ]] || continue

    # invoke npm by absolute path, via its own node — the interactive `npm` shell
    # function routes to pnpm when no package-lock.json is present, so a bare
    # `npm uninstall -g` here would remove the pnpm copy we mean to keep
    "$nodedir/bin/node" "$nodedir/bin/npm" uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || {
      echo "⛈️  failed to prune npm-global claude-code at $nodedir"
      echo "   fix: '$nodedir/bin/node' '$nodedir/bin/npm' uninstall -g @anthropic-ai/claude-code"
      return 1
    }
    echo "• pruned npm-global claude-code shadow at $(basename "$(dirname "$nodedir")")"
    pruned=1
  done

  [[ "$pruned" -eq 1 ]] || echo "• no npm-global claude-code shadows found"
}

configure_robot_brains() {
  #########################
  ## claude-code cli config
  ## ref: https://code.claude.com/docs/en/setup
  #########################

  # remove any npm-global copy that would outrank the pinned pnpm install
  prune_claude_code_shadows || return 1

  # converge the pnpm global install onto the pin (idempotent: a no-op when matched)
  pnpm install -g "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION_PINNED" || {
    echo "⛈️  failed to install claude-code@$CLAUDE_CODE_VERSION_PINNED"
    echo "   fix: pnpm install -g @anthropic-ai/claude-code@$CLAUDE_CODE_VERSION_PINNED"
    return 1
  }

  # patch:
  # - DISABLE_UPDATES: block all self-update paths (we manage claude via pnpm),
  #   which silences the "auto-update failed" startup nag
  # - disableClaudeAiConnectors: stop claude.ai connector auto-fetch, which
  #   silences the "N claude.ai connector needs auth · /mcp" nag (v2.1.182+ only)
  # - CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION: turn off prompt suggestions — the grey
  #   ghost text claude proposes inside its own input box (tab accepts it).
  #   the `/`-command menu and `@`-file completion are separate features and are
  #   NOT affected. opt-out shipped in claude 2.0.71 (anthropics/claude-code#13878)
  # - permissions.defaultMode=acceptEdits: sessions start in accept-edits mode so
  #   file edits apply without a prompt (shift+tab still cycles modes live)
  # note: the "switched to native installer" nag is NOT gated by settings.json —
  #   it needs DISABLE_INSTALLATION_CHECKS exported in the shell (see src/zshrc.sh)
  # note: the env block suits the prompt-suggestion flag because claude reads it as
  #   process.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION mid-session, well after
  #   settings load — unlike the boot-time checks, which need a real shell export
  local patch='{"env": {"DISABLE_AUTOUPDATER": "1", "DISABLE_UPDATES": "1", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false"}, "disableClaudeAiConnectors": true, "permissions": {"defaultMode": "acceptEdits"}}'
  local settings_file="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  if [[ -f "$settings_file" ]]; then
    # deep-merge patch into extant settings
    jq --argjson patch "$patch" '. * $patch' "$settings_file" > /tmp/claude-settings.json \
      && mv /tmp/claude-settings.json "$settings_file"
  else
    # create new settings file
    echo "$patch" > "$settings_file"
  fi
  echo "• claude-code updates + claude.ai connectors + prompt suggestions disabled"

  # drop the shell's cached command paths — we just removed a `claude` that may
  # have been resolved and cached earlier in this same shell
  if [[ -n "$ZSH_VERSION" ]]; then rehash; else hash -r 2>/dev/null || true; fi

  # verify the claude that actually resolves is the pinned pnpm copy.
  # .why = prune + install converge the filesystem, but PATH order decides which
  #   binary wins. assert the outcome rather than assume it (rule.forbid.failhide)
  local claude_path claude_version
  claude_path="$(command -v claude)" || {
    echo "⛈️  claude not found on PATH after install"
    echo "   fix: confirm PNPM_HOME ($HOME/.local/share/pnpm) is on PATH, then re-run sync.devenv.brains"
    return 1
  }

  claude_version="$("$claude_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ "$claude_version" != "$CLAUDE_CODE_VERSION_PINNED" ]]; then
    echo "⛈️  claude resolves to v${claude_version:-unknown}, expected the pinned v$CLAUDE_CODE_VERSION_PINNED"
    echo "   at:  $claude_path"
    echo "   why: another claude install outranks the pinned pnpm copy on PATH"
    echo "   fix: which -a claude   # find the shadow, then remove it at its source"
    return 1
  fi

  echo "• claude-code pinned at v$CLAUDE_CODE_VERSION_PINNED, resolves to $claude_path"
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
  for organization in {ehmpathy,ahbode,whodisio}; do
    gh repo list $organization --limit 1000 | while read -r repo _; do
      gh repo clone "$repo" "$HOME/git/$repo"
    done
  done
}
