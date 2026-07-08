#!/usr/bin/env bash
######################################################################
# pt4: terminal & editor
# fonts, ptyxis, terminal command, vim/neovim
######################################################################

install_fonts() {
  # firacode — ligatures for code
  sudo apt install fonts-firacode

  # Hack Nerd Font Mono — monospace with icons for neovim/neo-tree
  # ref: https://github.com/ryanoasis/nerd-fonts
  # note: "Mono" variant maintains strict monospace (icons don't break alignment)
  local font_dir="$HOME/.local/share/fonts"
  if ls "$font_dir"/Hack*.ttf &>/dev/null; then
    echo "• Hack Nerd Font already installed; skipped"
    return
  fi
  mkdir -p "$font_dir"
  local tmp_zip="/tmp/Hack-NerdFont.zip"
  curl -fsSL -o "$tmp_zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
  unzip -o "$tmp_zip" -d "$font_dir"
  rm "$tmp_zip"
  fc-cache -fv
  # set as system monospace font (required for VTE terminals like ptyxis)
  gsettings set org.gnome.desktop.interface monospace-font-name 'Hack Nerd Font Mono 12'
  echo "• Hack Nerd Font installed and set as system monospace"
}

install_ptyxis() {
  ##########################
  ## ptyxis terminal (rapid, gpu-accelerated, container-aware)
  ## ref: https://gitlab.gnome.org/chergert/ptyxis
  ## ref: https://ubuntuhandbook.org/index.php/2025/08/install-set-ptyxis-as-default-terminal-in-ubuntu-24-04-22-04/
  ## ref: https://documentation.ubuntu.com/desktop/en/latest/how-to/change-the-default-terminal/
  ##########################

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

  # register as a selectable alternative (kitty is the default — see configure_kitty_default)
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ptyxis.wrapper 50
}

configure_kitty_default() {
  # set kitty as the system default terminal (ctrl+alt+t / x-terminal-emulator)
  # install_kitty symlinks the tarball binary to /usr/local/bin/kitty, so look up
  # the real path rather than assume /usr/bin/kitty (which does not exist).
  local kitty_bin
  kitty_bin="$(command -v kitty)" || {
    echo "• kitty not installed; run install_kitty first; skipped"
    return 0
  }

  # register at higher priority than ptyxis (50) and force-select kitty
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$kitty_bin" 60
  sudo update-alternatives --set x-terminal-emulator "$kitty_bin"
  echo "• default terminal: kitty (x-terminal-emulator, $kitty_bin)"
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
setsid -f kitty --directory "$dir"
EOF
  sudo chmod +x /usr/bin/terminal
}

install_vim() {
  sudo apt install vim -y
}

install_neovim() {
  #########################
  ## neovim: from the official stable release tarball (version-pinned)
  ## ref: https://github.com/neovim/neovim/releases
  ##
  ## why tarball, not ppa:
  ##  - neovim-ppa/unstable ships dev snapshots (e.g. v0.12.0-dev) whose input
  ##    regressions double-emitted <CR>/<BS> inside nvim under kitty
  ##  - neovim-ppa/stable publishes NO neovim binary for noble (deps only)
  ##  - the official tarball is self-contained and pinnable
  ##
  ## integrity: neovim publishes NO gpg signature for release assets, so a
  ## pinned sha256 is the only tamper check available. the hash below came from
  ## github's api asset digest for v0.12.3 (server-computed). to bump: update
  ## version + sha256 together, from `gh api .../releases/tags/vX | .assets[].digest`.
  #########################
  local version="0.12.3"
  local archive="nvim-linux-x86_64.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/v${version}/${archive}"
  local sha256="c441b547142860bf01bcce39e36cbed185c41112813e15443b16e5237750724d"
  local tmp_dir="/tmp/nvim-install"

  # drop any ppa-managed neovim so /usr/bin/nvim can't shadow the tarball
  sudo add-apt-repository --remove ppa:neovim-ppa/unstable -y || true
  sudo add-apt-repository --remove ppa:neovim-ppa/stable -y || true
  sudo apt remove neovim neovim-runtime -y || true

  # fetch stable tarball
  rm -rf "$tmp_dir" && mkdir -p "$tmp_dir"
  curl -fsSL "$url" -o "$tmp_dir/$archive"

  # fail fast unless the download matches the pinned sha256
  if ! echo "${sha256}  $tmp_dir/$archive" | sha256sum -c - >/dev/null 2>&1; then
    echo "⛈️  neovim install aborted: sha256 mismatch (expected $sha256)"
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "✨ neovim tarball sha256 verified ($sha256)"

  # extract to /opt (extracts to /opt/nvim-linux-x86_64)
  sudo rm -rf /opt/nvim-linux-x86_64
  sudo tar -xzf "$tmp_dir/$archive" -C /opt
  rm -rf "$tmp_dir"

  # expose on PATH via /usr/local/bin (precedes /usr/bin)
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim

  # tree-sitter-cli required for nvim-treesitter parser compilation
  cargo install tree-sitter-cli
  # imagemagick required by image.nvim magick_cli processor to render pngs inline (via kitty graphics)
  sudo apt install imagemagick -y

  echo "• neovim v${version} installed to /opt/nvim-linux-x86_64 (nvim -> /usr/local/bin/nvim)"
  nvim --version | head -1
}

configure_neovim() {
  mkdir -p ~/.config/nvim
  cp "$HOME/git/more/dev-env-setup/src/init.lua" ~/.config/nvim/init.lua
  echo "• neovim config applied"
}

install_pqiv() {
  # lightweight image viewer for vim-style navigation
  sudo apt install pqiv -y
}

configure_pqiv() {
  # vim keybindings for pqiv
  # ref: https://github.com/phillipberndt/pqiv
  mkdir -p ~/.config
  cat > ~/.config/pqivrc << 'EOF'
[options]
zoom-level=1.0
disable-scaling=1

[keybindings]
h { shift_x(50) }
j { shift_y(-50) }
k { shift_y(50) }
l { shift_x(-50) }
gg { set_shift_align_corner(N) }
G { set_shift_align_corner(S) }
<Control>j { set_scale_level_relative(0.9) }
<Control>k { set_scale_level_relative(1.1) }
EOF
  echo "• pqiv config applied (~/.config/pqivrc)"
}
