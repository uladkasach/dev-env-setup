#!/usr/bin/env bash
######################################################################
# pt1a: system basics
# firefox, 1password extension, firefox prefs
######################################################################

install_firefox() {
  flatpak install flathub org.mozilla.firefox
  xdg-settings set default-web-browser org.mozilla.firefox.desktop
  sudo apt remove firefox
}

install_1password_extension() {
  browser https://addons.mozilla.org/en-US/firefox/addon/1password-x-password-manager/
}

install_firefox_color_extension() {
  browser https://addons.mozilla.org/en-US/firefox/addon/firefox-color/
}

install_vimium_extension() {
  browser https://addons.mozilla.org/en-US/firefox/addon/vimium-ff/
}

configure_firefox_theme() {
  # desert theme for firefox color extension
  # matches ptyxis/gitui/nvim desert palette
  local theme_url="https://color.firefox.com/?theme=XQAAAAIQAQAAAAAAAABBKYhm849SCia2CaaEGccwS-xMDPr_qlXDOMsy5fmNc7qTuOgZgZdB1JimDBY6_wyFhPNbQTHUNdhC5aOH-hbXzzZFdz54UfdCX_Q0U6BYOxbB4cKbN3-x8JbJB-nSYQTDMnJWVFqwFxW6UsMywRqsEjH6xrdahroi3D8vQwbLUkWN2HPFTCEwFJ-BNUTe2qbjSkITKQzctI3TSSXE5trErmv_7LBNAA"
  browser "$theme_url"
  echo "• firefox color theme opened (click 'Yes, apply theme' in browser)"
}

install_browser_command() {
  # quiet browser launcher for xdg-open, gh, etc
  # suppresses firefox flatpak sandbox noise
  mkdir -p ~/.local/bin
  cat > ~/.local/bin/browser << 'EOF'
#!/bin/sh
setsid -f flatpak run org.mozilla.firefox "$@" >/dev/null 2>&1
EOF
  chmod +x ~/.local/bin/browser
  echo "• browser command installed (~/.local/bin/browser)"
}

configure_firefox_prefs() {
  # find the default-release profile dir
  local ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
  local profile_dir
  profile_dir=$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)
  if [[ -z "$profile_dir" ]]; then
    echo "• firefox profile not found; skipped"
    return 1
  fi

  # clean new tab page: no topsites, no pocket, no sponsored, no highlights
  local prefs="$ff_root/$profile_dir/user.js"
  cat > "$prefs" << 'EOF'
// clean new tab page
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
user_pref("browser.newtabpage.activity-stream.discoverystream.enabled", false);
EOF

  echo "• firefox prefs configured (restart firefox to apply)"
}
