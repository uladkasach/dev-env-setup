#########################
## install vim
#########################
sudo apt install vim -y # note: ~/.zshrc already defines that this is defaulta

#########################
## install chrome
######################### 
rm ~/Downloads/google-chrome-stable_current_amd64.deb;
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -P ~/Downloads;
sudo dpkg -i ~/Downloads/google-chrome-stable_current_amd64.deb;
google-chrome; # open it; set it as your defualt

#########################
## install ssh + generate ssh key for your machine
#########################
sudo apt-get install ssh -y;
ssh-keygen; # use the default path to save the key; create your own password
cat ~/.ssh/id_rsa.pub; # <- view your public key
# add it to your github account manually
google-chrome https://github.com/settings/keys

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

# note: if git icon looks weird, make sure to install font that supports it: https://github.com/tonsky/FiraCode :
sudo apt install fonts-firacode

#########################
## change keybind of caps lock modifier -> control modifier, && caps lock -> escape
#########################
sudo apt install xcape -y;
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"; # make caps work as ctrl; https://unix.stackexchange.com/a/66657/77522
grep -qxF 'xcape -e "'"Caps_Lock=Escape"'"' ~/.profile || echo '\n# map caps key to escape if pressed on its own\nxcape -e "'"Caps_Lock=Escape"'"' >> ~/.profile # writes to `~/.profile` if that line is not alrady there; Why add to `~/.profile` specifically?: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980
grep -qxF 'xcape -e "'"Control_L=Escape"'"' ~/.profile || echo '\n# map caps key to escape if pressed on its own\nxcape -e "'"Control_L=Escape"'"' >> ~/.profile # writes to `~/.profile` if that line is not alrady there; Why add to `~/.profile` specifically?: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980

#########################
## add `alt` + `h/j/k/l` => left/up/down/right - per vim bindings
## - https://askubuntu.com/questions/1025765/how-to-map-alt-hjkl-keys-to-arrow-keys
## - https://unix.stackexchange.com/questions/65507/use-setxkbmap-to-swap-the-left-shift-and-left-control?noredirect=1&lq=1
## - https://wiki.archlinux.org/title/X_keyboard_extension
## - https://stackoverflow.com/questions/45021978/create-a-custom-setxkbmap-option
## - https://askubuntu.com/questions/876005/what-file-is-the-setxkbmap-option-rules-meant-to-take-and-how-can-i-add-keyboa
##
## note:
## - unfortunately ~/.profile does not pick up these changes on startup _and_ whenever system sleeps / bluetooth reconnects / other, the xmodmap gets wiped, so call the `use.keymap.vimnav` bash alias for now # TODO: make these mappings persist on session starts
#########################
XKB_SHARED_DIR=/usr/share/X11/xkb
XKB_VIMLIKE_ARROWS_OPTION_FILE=$XKB_SHARED_DIR/symbols/vimlike
# sudo vim $XKB_VIMLIKE_ARROWS_OPTION_FILE
sudo touch $XKB_VIMLIKE_ARROWS_OPTION_FILE
XKB_VIMLIKE_ARROWS_OPTION_DEFINITION='
partial alphanumeric_keys modifier_keys
xkb_symbols "arrows" {
  key <AC06> { [ h, H,  Left, Left ] };
  key <AC07> { [ j, J,  Down, Down ] };
  key <AC08> { [ k, K,    Up, Up ] };
  key <AC09> { [ l, L, Right, Right ] };
  key <RALT> { [ ISO_Level3_Shift, ISO_Level3_Shift, ISO_Level3_Shift, ISO_Level3_Shift ] };
  key <RWIN> { [ ISO_Level3_Shift, ISO_Level3_Shift, ISO_Level3_Shift, ISO_Level3_Shift ] };
  modifier_map Mod5 { ISO_Level3_Shift };
};
';
grep -qxF 'xkb_symbols "arrows"' $XKB_VIMLIKE_ARROWS_OPTION_FILE || echo $XKB_VIMLIKE_ARROWS_OPTION_DEFINITION | sudo tee $XKB_VIMLIKE_ARROWS_OPTION_FILE # https://askubuntu.com/questions/103643/cannot-echo-hello-x-txt-even-with-sudo
XKB_OPTIONS_REGISTRY_FILE=$XKB_SHARED_DIR/rules/evdev # can be identified by running `setxkbmap -query -verbose 10` and seeing where rules are loaded from
XKB_OPTION_VIMLIKE_ARROWS_REGISTRATION='
// vimlike arrow registration, added during dev-env-setup
! option        =       symbols
  vimlike:arrows = +vimlike(arrows)
';
sudo cp $XKB_OPTIONS_REGISTRY_FILE $XKB_OPTIONS_REGISTRY_FILE.bak
grep -qxF '  vimlike:arrows = +vimlike(arrows)' $XKB_OPTIONS_REGISTRY_FILE || echo $XKB_OPTION_VIMLIKE_ARROWS_REGISTRATION | sudo tee -a $XKB_OPTIONS_REGISTRY_FILE # https://askubuntu.com/questions/103643/cannot-echo-hello-x-txt-even-with-sudo
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier', 'vimlike:arrows']"; # !: we _append_ this option to the ctrl_modifier option from prior steps
gsettings get org.gnome.desktop.input-sources xkb-options


#########################
## make sure your pop-os laptop always starts in battery saver mode
#########################
grep -qxF 'system76-power profile battery' ~/.profile || echo '\n# start in battery saver\nsystem76-power profile battery' >> ~/.profile # writes to `~/.profile` if that line is not alrady there; Why add to `~/.profile` specifically?: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile/183980#183980

#########################
## install one password (https://support.1password.com/command-line-getting-started/)
#########################
browser https://app-updates.agilebits.com/product_history/CLI # <- check what the latest version is. we have it writen as 1.8.0 atm, but it will probably change by the time you use it. update your commands accordingly
wget https://cache.agilebits.com/dist/1P/op/pkg/v1.8.0/op_linux_386_v1.8.0.zip -P ~/Downloads;
unzip ~/Downloads/op_linux_386_v1.8.0.zip -d ~/Downloads/op_linux_386_v1.8.0;
gpg --receive-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22;
gpg --verify ~/Downloads/op_linux_386_v1.8.0/op.sig ~/Downloads/op_linux_386_v1.8.0/op;
sudo mv ~/Downloads/op_linux_386_v1.8.0/op /usr/local/bin;
op --version;

# signin
op signin my.1password.com wendy_appleseed@example.com; # swap with your email
op.signin; # use this bash alias to signin subsequently; it runs `eval $(op signin my)` for us

# see docs
google-chrome https://support.1password.com/command-line-getting-started/
google-chrome https://support.1password.com/command-line/
# for example, you can backup aws config with `op create document ~/.aws/credentials --title .aws/credentials`

########################
## set git user
#######################
git config --global user.email "u...k...@gmail.com" # change me to your email
git config --global user.name "U... K..." # change me to your name
git config --global pull.ff only # make sure that pull only ever automatically fasts forward
git config --global init.defaultBranch main # default root branch name to `main`
git config --global alias.lg "log --pretty=format:'%C(yellow)%h %Cred%ad %C(cyan)%an%Cgreen%d %Creset%s' --date=short" # more concise alt to git log
git config --global alias.root 'rev-parse --show-toplevel' # e.g., `cd $(git root)`
git config --global alias.recommit 'commit --amend --no-edit' # e.g., to update the last commit in place
git config --global alias.shove 'push origin HEAD --force-with-lease' # e.g., git push current branches commits, as long as we have all the commits already too

#######################
## install bash alias dependencies
#######################
sudo apt install -y xclip # required for pbpaste, pbcopy
sudo apt install -y jq  # required for manipulating json in terminal


#########################
## install codium
#########################
# per https://vscodium.com/
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/etc/apt/trusted.gpg.d/vscodium.gpg
echo 'deb https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main' | sudo tee --append /etc/apt/sources.list.d/vscodium.list
sudo apt update && sudo apt install codium -y

# use microsoft extensions lib
# sudo find / -name product.json # reference for finding the full one
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

#########################
## install node + npm + nvm
#########################
browser https://github.com/nvm-sh/nvm; # check if newer version avail; update the below version if it is
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash;
nvm install 16 # and install latest version

#########################
## install drop box
#########################
google-chrome https://www.dropbox.com/install-linux # see what the latest version is; update the link below if its changed
wget https://linux.dropbox.com/packages/ubuntu/dropbox_2020.03.04_amd64.deb -P ~/Downloads;
sudo dpkg -i ~/Downloads/dropbox_2020.03.04_amd64.deb;
# now start dropbox manually; super + / "dropbox"; alt, try `dropbox start`?

##########################
## install aws cli
##########################
sudo apt-get install awscli -y;

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
#########################
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo groupadd docker
sudo usermod -aG docker $USER # run w/o root attempt 1
sudo gpasswd -a $USER docker # run w/o root attempt 2
su - $USER # relogin
docker --version
docker run hello-world # check we can run without root
sudo apt install -y docker-compose

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
# usage e.g.,:
#  mkdir -p ~/.vpn && op get document .vpn/main.connection.ovpn --output ~/.vpn/main.connection.ovpn
#  sudo openvpn --config ~/.vpn/main.connection.ovpn

########################
## add github cli tool; https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt
#######################
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y

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
# sudo apt install -y gnome-shell-extension-appindicator gnome-shell-extension-system-monitor  # show cpu usage in pop os bar; note: will need to restart before it shows
sudo apt install gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 gnome-system-monitor && echo 'install the system monitor extension through website for now...' && browser https://extensions.gnome.org/extension/3010/system-monitor-next/ # https://github.com/mgalgs/gnome-shell-system-monitor-applet ; # TODO: switch to not using `-next` version when its supported again
sudo apt install -y gir1.2-gst-plugins-base-1.0 && echo 'install the radio extension through website for now...' && browser https://extensions.gnome.org/extension/836/internet-radio/ # https://github.com/hslbck/gnome-shell-extension-radio
sudo apt install -y gnome-shell-pomodoro # show pomodoro extensinon
logout # login logout of DE
# then search "extensions" in settings and turn them on manually

#######################
## restore gnome-extension-radio channel-list
#######################
mkdir -p ~/.gse-radio \
  && rm ~/.gse-radio/channelList.json
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
flatpak install flathub com.slack.Slack

######################
## install proton vpn
## https://protonvpn.com/support/linux-ubuntu-vpn-setup/
######################
wget https://protonvpn.com/download/protonvpn-stable-release_1.0.1-1_all.deb -P ~/Downloads # check if theres a newer version of the repo install, at the link above;
sudo dpkg -i ~/Downloads/protonvpn-stable-release_1.0.1-1_all.deb;
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


