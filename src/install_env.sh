#########################
## enable ctrl-c and ctrl-v as copy and paste in the terminal
## ref: https://askubuntu.com/questions/53688/making-ctrlc-copy-text-in-gnome-terminal
#########################
sudo apt install gconf2
gconftool-2 -t str -s /apps/gnome-terminal/keybindings/copy "<Control>c"
gconftool-2 -t str -s /apps/gnome-terminal/keybindings/paste "<Control>v"

#########################
## rebind interrupt key to ctrl+x
## ref: https://forums.justlinux.com/showthread.php?127575-Saving-stty-settings-permanently-with-automatic-read; https://stackoverflow.com/a/25391867/3068233; https://forums.justlinux.com/showthread.php?105417-stty-erase-in-bash*; https://askubuntu.com/questions/61543/stty-doesnt-work
#########################
stty intr ^X
grep -qxF 'stty intr ^X' ~/.bashrc || echo '\n# bind interrupt key to ctrl-x\stty intr ^X' >> ~/.bashrc # writes to `~/.bashrc` if that line is not alrady there; Why add to `~/.bashrc` specifically?: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980

#########################
## install vim
#########################
sudo apt install vim -y # note: ~/.zshrc already defines that this is default

#############################
## for happiness, set swappiness
## keeps os feel snappy faster. if you have 32gb ram or more, this is for you
## ref: https://wiki.debian.org/swappiness
#############################
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf # This tells linux: "prefer keeping stuff in RAM; only swap when truly necessary."

#############################
## keyd - remap keys for optimal experience
#############################
install_keyd() {
  sudo add-apt-repository -y ppa:keyd-team/ppa
  sudo apt-get update
  sudo apt-get install -y keyd
  # symlink keyd.rvaiya -> keyd for convenience
  sudo ln -sf /usr/bin/keyd.rvaiya /usr/bin/keyd
  sudo systemctl enable --now keyd
}
install_keyd

upsert_keyd_config() {
  sudo mkdir -p /etc/keyd
  sudo rm -f /etc/keyd/*.conf 2>/dev/null || true
  sudo tee /etc/keyd/default.conf >/dev/null <<'EOF'
[ids]
*

[global]
# if capslock held > 200ms, skip the escape tap (helps with ctrl+click)
overload_tap_timeout = 200

[main]
# capslock = control (held) / escape (tapped)
capslock = overload(control, esc)

# disable disruptive keys
coffee  = noop
sleep   = noop
suspend = noop
power   = noop

# vim-style arrows with right alt, right ctrl, or right meta (magic keyboard)
rightalt = layer(vimarrows)
rightcontrol = layer(vimarrows)
rightmeta = layer(vimarrows)

[vimarrows]
h = left
j = down
k = up
l = right
EOF
  sudo systemctl restart keyd
}
upsert_keyd_config


#########################
## install keynav
##
## ref
##  - https://www.semicomplete.com/projects/keynav/
##
## notes
##  - `ctrl` + `;` -> begin keynav selection
##  - `h`, `i`, `j`, `l` -> select the part of the screen
##  - `shift` + `h`,`i`,`j`,`k` -> change the last selection you made to the new key
##  - `space` -> click on selection
##  - `semicolon` -> move to the selection
#########################
sudo apt-get install keynav
grep -qxF 'keynav' ~/.profile || echo '\n# start keynav in background\n(keynav && echo "keynav started" || echo "keynav already running") &' >> ~/.profile # writes to `~/.profile` if that line is not alrady there; Why add to `~/.profile` specifically?: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980


##########################
## install firefox via flatpak (we like sandboxes)
##########################
flatpak install flathub org.mozilla.firefox
xdg-settings set default-web-browser org.mozilla.firefox.desktop
sudo apt remove firefox

##########################
## install ptyxis terminal (rapid, gpu-accelerated, container-aware)
## ref: https://gitlab.gnome.org/chergert/ptyxis
## ref: https://ubuntuhandbook.org/index.php/2025/08/install-set-ptyxis-as-default-terminal-in-ubuntu-24-04-22-04/
## ref: https://documentation.ubuntu.com/desktop/en/latest/how-to/change-the-default-terminal/
##########################
install_ptyxis() {
  # skip if ptyxis is already the default terminal (e.g., ubuntu 25.10+, gnome 47+)
  local current_terminal
  current_terminal=$(readlink -f /usr/bin/x-terminal-emulator 2>/dev/null || echo "")
  if [[ "$current_terminal" == *ptyxis* ]]; then
    echo "• ptyxis already default terminal; skipped"
    return 0
  fi

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

  # register and set as default terminal (ctrl+alt+t)
  sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/ptyxis.wrapper 50
  sudo update-alternatives --set x-terminal-emulator /usr/bin/ptyxis.wrapper
}
install_ptyxis

configure_ptyxis() {
  # restore ptyxis keybindings and preferences
  # ref: https://www.garret.is/using/ptyxis/
  #
  # howto export your current ptyxis config for backup:
  #   cat ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings/keyfile
  #
  # howto update: after changes via ptyxis preferences gui, re-export and paste below
  #
  mkdir -p ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings
  tee ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings/keyfile > /dev/null << 'EOF'
[org/gnome/Ptyxis]
profile-uuids=['48d4f1a48e2fa956aa1f108e697f9492']
default-profile-uuid='48d4f1a48e2fa956aa1f108e697f9492'
window-size=(140, 74)
use-system-font=false
font-name='Monospace 12'

[org/gnome/Ptyxis/Shortcuts]
copy-clipboard='<Shift><Control>c'
paste-clipboard='<Shift><Control>v'
select-all='<Control>a'
new-window='<Control>backslash'
close-window='<Control>q'
set-title='<Shift><Control>t'
new-tab='<Control>t'
tab-overview='<Control>o'
close-tab='<Shift><Control>w'
move-previous-tab='<Control>h'
move-next-tab='<Control>l'

[org/gnome/Ptyxis/Profiles/48d4f1a48e2fa956aa1f108e697f9492]
palette='Desert'
label='default'
cell-height-scale=1.0
EOF
}
configure_ptyxis

# #########################
# ## install chrome
# #########################
# wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P ~/Downloads;
# sudo apt install ~/Downloads/google-chrome-stable_current_amd64.deb;
# google-chrome; # open it; set it as your defualt

#########################
## install ssh + generate ssh key for your machine
#########################
sudo apt-get install ssh -y;
ssh-keygen; # use the default path to save the key; create your own password
cat ~/.ssh/id_rsa.pub; # <- view your public key
# add it to your github account manually
browser https://github.com/settings/keys

########################
## install 1password chrome
########################
# install the chrome extension
browser https://chrome.google.com/webstore/detail/1password-%E2%80%93-password-mana/aeblfdkhhhdcdjpifhhbdiojplfjncoa
# update the extension keyboard shortcut
browser chrome://extensions/shortcuts

########################
## clone this repo
#########################
mkdir -p ~/git/more;
git clone git@github.com:uladkasach/dev-env-setup.git ~/git/more/dev-env-setup;

#########################
## install zsh + oh-my-zsh + spaceship theme
#########################
sudo apt install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" && ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
cp ~/git/more/dev-env-setup/src/bash_aliases.sh ~/.bash_aliases # reset from backup the aliases config
cp ~/git/more/dev-env-setup/src/zshrc.sh ~/.zshrc # reset from backup the zsh config

# make sure we use zsh by default
echo "
exec zsh
" >> ~/.bashrc

# now open a new terminal
gnome-terminal

# note: if git icon looks weird, make sure to install font that supports it: https://github.com/tonsky/FiraCode :
sudo apt install fonts-firacode


#########################
## make sure your pop-os laptop always starts in battery saver mode
#########################
grep -qxF 'system76-power profile battery' ~/.profile || echo '\n# start in battery saver\nsystem76-power profile battery' >> ~/.profile # writes to `~/.profile` if that line is not alrady there; Why add to `~/.profile` specifically?: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980

#########################
## install one password (https://support.1password.com/command-line-getting-started/)
#########################
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
sudo tee /etc/apt/sources.list.d/1password.list && \
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ && \
curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol && \
sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 && \
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg && \
sudo apt update && sudo apt install 1password-cli
op --version;

# signin
op account add --address my.1password.com --email user@example.org # swap with your email
op.signin; # use this bash alias to signin subsequently; it runs `eval $(op signin my)` for us

# see docs
browser https://support.1password.com/command-line-getting-started/
browser https://support.1password.com/command-line/
# for example, you can backup aws config with `op create document ~/.aws/credentials --title .aws/credentials`

########################
## set git user
#######################
git config --global user.email "u...k...@gmail.com" # change me to your email
git config --global user.name "U... K..." # change me to your name
git config --global pull.ff only # make sure that pull only ever automatically fasts forward
git config --global init.defaultBranch main # default root branch name to `main`

#######################
## set git aliases
#######################
git config --global alias.lg "log --pretty=format:'%C(yellow)%h %Cred%ad %C(cyan)%an%Cgreen%d %Creset%s' --date=short" # more concise alt to git log
git config --global alias.root 'rev-parse --show-toplevel' # e.g., `cd $(git root)`
git config --global alias.recommit 'commit --amend --no-edit' # e.g., to update the last commit in place
git config --global alias.shove 'push origin HEAD --force-with-lease' # e.g., git push current branches commits, as long as we have all the commits already too

git config --global alias.release '!bash -c "source ~/.bash_aliases && git_alias_release \"\$@\"" --'
git config --global alias.tree '!bash -c "source ~/.bash_aliases && git_alias_tree \"\$@\"" --'
git config --global alias.grab '!bash -c "source ~/.bash_aliases && git_alias_grab \"\$@\"" --'

#######################
## install bash alias dependencies
#######################
sudo apt install -y xclip # required for pbpaste, pbcopy
sudo apt install -y jq # required for manipulating json in terminal
sudo apt install -y tree # required for tree view of directories

#########################
## install codium
#########################
# per https://vscodium.com/
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/etc/apt/trusted.gpg.d/vscodium.gpg
echo 'deb https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main' | sudo tee --append /etc/apt/sources.list.d/vscodium.list
sudo apt update && sudo apt install codium -y

# use microsoft extensions lib
# sudo find / -name product.json # reference for finding the full one
mkdir ~/.config/VSCodium; # this dir may already exist if you've opened codium before
touch ~/.config/VSCodium/product.json;
echo "
{
  \"extensionsGallery\": {
    \"serviceUrl\": \"https://marketplace.visualstudio.com/_apis/public/gallery\",
    \"cacheUrl\": \"https://vscode.blob.core.windows.net/gallery/index\",
    \"itemUrl\": \"https://marketplace.visualstudio.com/items\",
    \"controlUrl\": \"\",
    \"recommendationsUrl\": \"\"
  }
}
" >> ~/.config/VSCodium/product.json;

# setup copilot; https://github.com/VSCodium/vscodium/discussions/1487
sudo vim /usr/share/codium/resources/app/product.json; # replace "GitHub.copilot" to ["inlineCompletions","inlineCompletionsNew","inlineCompletionsAdditions","textDocumentNotebook","interactive","terminalDataWriteEvent"]
echo "manually sign out of github in the bottom left corner user icon in vscodium"
echo "manually press sign into github copilot in that same link. it will prompt to enter a personal-access-token via web."
echo "if the pat generated via link doesnt work, try again but instead of using that web url, do the following steps to get a working token"
curl https://github.com/login/device/code -X POST -d 'client_id=01ab8ac9400c4e429b23&scope=user:email'; # request auth code for vscodium+copilot
browser https://github.com/login/device/ # enter your user_code to grant this vscodeium client_id access to your email
export YOUR_DEVICE_CODE="__your_device_code__" # get the device code from earlier
curl https://github.com/login/oauth/access_token -X POST -d "client_id=01ab8ac9400c4e429b23&scope=user:email&device_code=$YOUR_DEVICE_CODE&grant_type=urn:ietf:params:oauth:grant-type:device_code" # exchange it for an access token

# restore settings from backup
codium --install-extension zokugun.sync-settings
cp ~/git/more/dev-env-setup/codium/sync.settings.yml ~/.config/VSCodium/User/globalStorage/zokugun.sync-settings/settings.yml # install our sync settings
codium && echo 'run the "Sync Settings: Download (repository -> user)" command' && echo 'open the Sync Settings output pane to see install progress'


#########################
## install node + npm via fnm (fast node manager)
## ref: https://github.com/Schniz/fnm
#########################
curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fnm install --lts # install latest lts version

#########################
## install drop box
#########################
browser https://www.dropbox.com/install-linux # see what the latest version is; update the link below if its changed
wget https://linux.dropbox.com/packages/ubuntu/dropbox_2020.03.04_amd64.deb -P ~/Downloads;
sudo apt install ~/Downloads/dropbox_2020.03.04_amd64.deb;
dropbox start -i; # install the dropbox daemon and start it for the first time

##########################
## install aws cli
## https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
##########################
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# restore config into '~/.aws`
mkdir -p ~/.aws
op get document .aws/config --output ~/.aws/config
op get document .aws/credentials --output ~/.aws/credentials

# test installation
use.ahbode.dev # alias was defined by `./bash_aliases`
aws sts get-caller-identity

#########################
## install terraform w/ tfenv
#########################
git clone https://github.com/tfutils/tfenv.git ~/.tfenv

# add tfenv to $PATH
mkdir -p ~/.local/bin/
. ~/.profile
ln -s ~/.tfenv/bin/* ~/.local/bin
. ~/.profile

# and test install
which tfenv

#########################
## install docker + docker compose
## ref: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
#########################
# add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# add the repository to apt sources:
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
sudo usermod -aG docker $USER # run w/o root attempt 1
sudo gpasswd -a $USER docker # run w/o root attempt 2

# verify the installation
docker --version # verify it was installed
docker run hello-world # verify we can run without root
docker compose version # verify we installed docker compose

#########################
## install psql
#########################
sudo apt-get install -y postgresql-client

#########################
## bump max files watched
##
## otherwise, we'll have errors watching files
#########################
# per https://stackoverflow.com/a/32600959/3068233
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p

#########################
## vpn client (https://support.system76.com/articles/use-openvpn/)
#########################
sudo apt install openvpn network-manager-openvpn-gnome -y

#########################
## vpn connections
#########################
mkdir -p ~/.vpn \
  && op get document .vpn/ahbode.dev.vpn.main.connection.ovpn --output ~/.vpn/ahbode.dev.vpn.main.connection.ovpn \
  && op get document .vpn/ahbode.prod.vpn.main.connection.ovpn --output ~/.vpn/ahbode.prod.vpn.main.connection.ovpn;

########################
## add github cli tool; https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt
#######################
type -p curl >/dev/null || sudo apt install curl -y # install curl if not already installed
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y
# login to gh
gh auth login

#######################
## clone all repos in the organizations you care about
#######################
for organization in {ehmpathy,ahbode}; do
  gh repo list $organization --limit 1000 | while read -r repo _; do
    gh repo clone "$repo" "$HOME/git/$repo"
  done
done

#######################
## install ngrok
#######################
wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -P ~/Downloads;
unzip ~/Downloads/ngrok-stable-linux-amd64.zip -d ~/Downloads/ngrok-stable-linux-amd64;
sudo mv ~/Downloads/ngrok-stable-linux-amd64/ngrok /usr/bin/ngrok
ngrok authtoken __from_you_account_settings__
ngrok help

#######################
## install gnome extensions: https://support.system76.com/articles/customize-gnome
#######################
sudo apt install lm-sensors gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 gnome-system-monitor && echo 'install the system monitor extension through website for now...' && browser https://extensions.gnome.org/extension/3010/system-monitor-next/ # https://github.com/mgalgs/gnome-shell-system-monitor-applet ; # TODO: switch to not using `-next` version when its supported again
sudo apt install -y gir1.2-gst-plugins-base-1.0 && echo 'install the radio extension through website for now...' && browser https://extensions.gnome.org/extension/836/internet-radio/ # https://github.com/hslbck/gnome-shell-extension-radio
sudo apt install -y gnome-shell-pomodoro # show pomodoro extensinon
logout # login logout of DE
# then search "extensions" in settings and turn them on manually

#######################
## restore gnome-extension-radio channel-list
#######################
mkdir -p ~/.gse-radio \
  && rm ~/.gse-radio/channelList.json \
  && op get document .gse-radio/channelList.json --output ~/.gse-radio/channelList.json

#######################
## install support for AAC+ audio format codec (for comedy-radio.ru stream)
#######################
# comedy-radio.ru : https://pub0101.101.ru:8000/stream/air/aac/64/202
sudo apt-get install -y ubuntu-restricted-extras libavcodec58 ffmpeg

#######################
## make sure that nightlight is enabled
#######################
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true # https://askubuntu.com/questions/1246195/how-to-turn-on-night-light-blue-light-filter-in-ubuntu-20-04

#######################
## make sure that automatic brightness is disabled
#######################
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false # https://itsfoss.com/automatic-brightness-ubuntu/

#######################
## bind the screen capture shortcuts
## - "open print screen ui" to ctrl-shift-alt-p
## - "open record screen ui" to ctrl-shift-alt-r
##
## ref
## - get current value `gsettings get org.gnome.shell.keybindings show-screenshot-ui`
## - list all values in schema `gsettings list-recursively org.gnome.shell.keybindings`
#######################
gsettings set org.gnome.shell.keybindings show-screenshot-ui "['Print', '<Primary><Shift><Alt>P']"
gsettings set org.gnome.shell.keybindings show-screen-recording-ui "['<Ctrl><Shift><Alt>R']"

######################
## install flatpak; https://flatpak.org/setup/Pop!_OS
######################
sudo apt install flatpak
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

######################
## install client apps
######################
flatpak install flathub com.spotify.Client
flatpak install flathub com.jetbrains.DataGrip
flatpak install flathub com.slack.Slack # flatpak update com.slack.Slack

######################
## install proton vpn
## https://protonvpn.com/support/linux-ubuntu-vpn-setup/
######################
browser https://protonvpn.com/support/linux-ubuntu-vpn-setup/ # check for latest version, update the below versions as needed
wget https://protonvpn.com/download/protonvpn-stable-release_1.0.3-2_all.deb -P ~/Downloads
sudo apt install ~/Downloads/protonvpn-stable-release_1.0.3-2_all.deb;
sudo apt update;
sudo apt-get install -y protonvpn;
sudo apt install -y gnome-shell-extension-appindicator gir1.2-appindicator3-0.1; # system tray icon

######################
## install app image launcher
## https://github.com/TheAssassin/AppImageLauncher
######################
sudo apt install software-properties-common
sudo add-apt-repository ppa:appimagelauncher-team/stable
sudo apt update
sudo apt install appimagelauncher


######################
## dont suspend on lid close
## ref: https://ubuntuhandbook.org/index.php/2020/05/lid-close-behavior-ubuntu-20-04/
######################
LOGIND_CONF="/etc/systemd/logind.conf"

# Remove any existing lines for these settings (commented or not)
for key in HandlePowerKey HandleSuspendKey HandleHibernateKey HandleRebootKey HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked; do
    sudo sed -i "/^#*${key}=/d" "$LOGIND_CONF"
done

# Append the new settings
sudo tee -a "$LOGIND_CONF" > /dev/null <<'EOF'

# use terminal instead; keyboard misfire is too common
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleRebootKey=ignore

# use terminal instead; display disconnect is too common
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

# Note: Run 'sudo systemctl restart systemd-logind' to apply (will log you out)
# Or just reboot after running this script
