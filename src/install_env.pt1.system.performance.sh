#!/usr/bin/env bash
######################################################################
# pt1b: system performance
# sysctl (inotify, swappiness), swapfile, fonts, firefox
######################################################################

install_firefox() {
  flatpak install flathub org.mozilla.firefox
  xdg-settings set default-web-browser org.mozilla.firefox.desktop
  sudo apt remove firefox
}

install_1password_extension() {
  browser https://addons.mozilla.org/en-US/firefox/addon/1password-x-password-manager/
}

configure_firefox_theme() {
  # find the default-release profile dir
  local ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
  local profile_dir
  profile_dir=$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)
  if [[ -z "$profile_dir" ]]; then
    echo "• firefox profile not found; skipped"
    return 1
  fi
  local full_path="$ff_root/$profile_dir"

  # copy userChrome.css
  mkdir -p "$full_path/chrome"
  cp "$HOME/git/more/dev-env-setup/src/firefox.userChrome.css" "$full_path/chrome/userChrome.css"

  # enable userChrome.css loading (requires restart)
  local prefs="$full_path/user.js"
  grep -qF 'toolkit.legacyUserProfileCustomizations.stylesheets' "$prefs" 2>/dev/null || \
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' >> "$prefs"

  echo "• firefox desert theme installed (restart firefox to apply)"
}

configure_sysctl() {
  #########################
  ## bump max files watched
  ## per https://stackoverflow.com/a/32600959/3068233
  #########################
  echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

  #############################
  ## set swappiness — prefer RAM over swap
  ## ref: https://wiki.debian.org/swappiness
  #############################
  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
}

configure_swapfile() {
  #############################
  ## add swapfile for overflow (complements zram)
  ##
  ## why: zram compresses cold pages in RAM (fast, ~16gb default)
  ##      when zram fills, overflow goes to disk swap
  ##      more disk swap = more headroom for cold pages
  ##
  ## hierarchy: RAM -> zram (compressed RAM) -> disk swap (SSD)
  #############################
  local swapfile="/swapfile"
  local size="36G"

  # skip if swapfile already exists and is active
  if swapon --show | grep -q "$swapfile"; then
    echo "• swapfile already active; skipped"
    return 0
  fi

  # create swapfile if it doesn't exist
  if [[ ! -f "$swapfile" ]]; then
    echo "• create ${size} swapfile..."
    sudo fallocate -l "$size" "$swapfile"
    sudo chmod 600 "$swapfile"
    sudo mkswap "$swapfile"
  fi

  # activate swapfile
  sudo swapon "$swapfile"

  # add to fstab if not already present
  if ! grep -q "$swapfile" /etc/fstab; then
    echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "• swapfile added to /etc/fstab"
  fi

  echo "• swapfile configured: $size"
}

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

######################################################################
# run
######################################################################
install_firefox
install_1password_extension
configure_firefox_theme
configure_sysctl
configure_swapfile
install_fonts
