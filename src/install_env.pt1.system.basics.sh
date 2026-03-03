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
