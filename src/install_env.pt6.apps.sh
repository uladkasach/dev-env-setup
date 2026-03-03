#!/usr/bin/env bash
######################################################################
# pt6: client apps
# dropbox, spotify, datagrip, slack, protonvpn, codium
######################################################################

install_dropbox() {
  browser https://www.dropbox.com/install-linux # see what the latest version is; update the link below if its changed
  wget https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2026.01.15_amd64.deb -P ~/Downloads
  sudo apt install ~/Downloads/dropbox_2026.01.15_amd64.deb
  dropbox start -i
}

install_flatpak_apps() {
  flatpak install flathub com.spotify.Client
  flatpak install flathub com.jetbrains.DataGrip
  flatpak install flathub com.slack.Slack # flatpak update com.slack.Slack
}

install_protonvpn() {
  ######################
  ## ref: https://protonvpn.com/support/linux-ubuntu-vpn-setup/
  ######################
  browser https://protonvpn.com/support/linux-ubuntu-vpn-setup/ # check for latest version, update the below versions as needed
  wget https://protonvpn.com/download/protonvpn-stable-release_1.0.3-2_all.deb -P ~/Downloads
  sudo apt install ~/Downloads/protonvpn-stable-release_1.0.3-2_all.deb
  sudo apt update
  sudo apt-get install -y protonvpn
  sudo apt install -y gnome-shell-extension-appindicator gir1.2-appindicator3-0.1 # system tray icon
}

install_codium() {
  #########################
  ## ref: https://vscodium.com/
  #########################
  wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/etc/apt/trusted.gpg.d/vscodium.gpg
  echo 'deb https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main' | sudo tee --append /etc/apt/sources.list.d/vscodium.list
  sudo apt update && sudo apt install codium -y

  # use microsoft extensions lib
  mkdir -p ~/.config/VSCodium
  cat > ~/.config/VSCodium/product.json << 'EOF'
{
  "extensionsGallery": {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
    "itemUrl": "https://marketplace.visualstudio.com/items",
    "controlUrl": "",
    "recommendationsUrl": ""
  }
}
EOF
}

configure_codium_copilot() {
  # setup copilot; https://github.com/VSCodium/vscodium/discussions/1487
  sudo vim /usr/share/codium/resources/app/product.json # replace "GitHub.copilot" to ["inlineCompletions","inlineCompletionsNew","inlineCompletionsAdditions","textDocumentNotebook","interactive","terminalDataWriteEvent"]
  echo "manually sign out of github in the bottom left corner user icon in vscodium"
  echo "manually press sign into github copilot in that same link. it will prompt to enter a personal-access-token via web."
  echo "if the pat generated via link doesnt work, try again but instead of using that web url, do the following steps to get a working token"
  curl https://github.com/login/device/code -X POST -d 'client_id=01ab8ac9400c4e429b23&scope=user:email'
  browser https://github.com/login/device/
  export YOUR_DEVICE_CODE="__your_device_code__"
  curl https://github.com/login/oauth/access_token -X POST -d "client_id=01ab8ac9400c4e429b23&scope=user:email&device_code=$YOUR_DEVICE_CODE&grant_type=urn:ietf:params:oauth:grant-type:device_code"
}

configure_codium_sync() {
  codium --install-extension zokugun.sync-settings
  cp ~/git/more/dev-env-setup/codium/sync.settings.yml ~/.config/VSCodium/User/globalStorage/zokugun.sync-settings/settings.yml
  codium && echo 'run the "Sync Settings: Download (repository -> user)" command' && echo 'open the Sync Settings output pane to see install progress'
}
