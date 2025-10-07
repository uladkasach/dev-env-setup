# open notes
alias notes='vim ~/git/notes/main.txt'

# copy paste
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'

# copy uuid into clipboard
alias getuuid='uuidgen | tr -d "'"\n"'" | pbcopy && echo "'"  ✔ uuid was copied"'"'

# quick test alias
alias ju='npx jest -c jest.unit.config.(ts|js)'
alias ji='npx jest -c jest.integration.config.(ts|js)'
alias ja='npx jest -c jest.acceptance.config.(ts|js)'
alias jal='LOCALLY=true ja'

# quick terraform alias
alias tf='terraform'

# aws profiles
alias use.tugether='export AWS_PROFILE=tugether'
alias use.ahbode.dev='export AWS_PROFILE=ahbode.dev'
alias use.ahbode.prod='export AWS_PROFILE=ahbode.prod'
alias use.ahction='export AWS_PROFILE=ahction'
alias use.whodis.prod='export AWS_PROFILE=whodis.prod'
alias use.alistokrad.prod='export AWS_PROFILE=alistokrad.prod'

# ahbode 3rd-party credentials
alias use.ahbode.fastly='export FASTLY_API_KEY=$(op get item fastly.ahbode.apikey | jq -r .details.password)'
alias use.ahbode.yelp='export YELP_API_KEY=$( op get item 2jhey5edfilrwjwhjn6mvtk7au  | jq -r ".details.sections[1].fields[1].v" )'
alias use.ahbode.bannerbear='export BANNER_BEAR_API_KEY=$( op get item bannerbear.ahbode.apikey | jq -r .details.password)'
alias use.ahbode.googlecloudplatform.apikey='export GCP_API_KEY=$(op get item ahbode.googlecloudplatform.providerstorefronts.apikey | jq -r .details.password)'
alias use.ahbode.googlecloudplatform.keyfilejson='export GCLOUD_KEYFILE_JSON=$(op get item ahbode.googlecloudplatform.providerstorefronts.admin.serviceaccountkey | jq -r .details.password)'

# vpn
alias use.ahbode.dev.vpn="sudo openvpn --config ~/.vpn/ahbode.dev.vpn.main.connection.ovpn"
alias use.ahbode.prod.vpn="sudo openvpn --config ~/.vpn/ahbode.prod.vpn.main.connection.ovpn"

# github token
alias use.github.admin='export GITHUB_TOKEN=$(op item get github.admin.pat --fields label=password --format json | jq -r .value)'

# terraform caching, for when on slow internet
alias use.terraform.caching='mkdir -p $HOME/.terraform.d/plugin-cache && export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' # https://www.terraform.io/docs/cli/config/config-file.html#provider-plugin-cache

# networking utilities
alias use.mtu.1400='sudo ifconfig wlp113s0 mtu 1400' # for when you're on older infra networks; https://serverfault.com/a/670081/276221; https://www.cloudflare.com/learning/network-layer/what-is-mtu/

# make it easy to manually update the keymappings, in case they drop off for some reason
alias use.keymap.altswap='setxkbmap -option altwin:swap_lalt_lwin' # https://unix.stackexchange.com/a/367016/77522

# make signing into onepass easier
alias op.signin='eval $(op signin)'

# make it easier to open the browser
alias browser='google-chrome & disown'

# make it easier to open the terminal
alias terminal='gnome-terminal & disown'

# make it easier to open the file manager
alias files='nautilus & disown'

# make it easy to speed test internet connection
alias speedtest='wget --output-document=/dev/null http://speedtest.wdc01.softlayer.com/downloads/test500.zip'

# make it easy to change brightness beyond default brightness range; e.g., brightness 0.6
alias brightness='xrandr --output eDP-1 --brightness'

# make it easy to restart utils
alias restart.bluetooth='bluetoothctl power on && systemctl restart bluetooth'
alias restart.wifi='systemctl restart NetworkManager.service'

# make it easy to update bashalias
alias devenv.sync.bashalias='cp ~/git/more/dev-env-setup/src/bash_aliases.sh ~/.bash_aliases && source ~/.bash_aliases'

# make it easy to pull down the devenv repo
alias devenv.sync.repo='cd ~/git/more/dev-env-setup && git checkout main && git pull origin HEAD'

# make it easy to suspend and restart and shutdown
alias power.suspend='systemctl suspend' # todo, swap to `suspend-then-hibernate` when supported
alias power.off='shutdown -h now '
alias power.restart='reboot'

# make it easy to work with bluetooth devices
alias bluetooth.devices='bluetoothctl devices';
alias bluetooth.connect='bluetoothctl connect';
alias bluetooth.disconnect='bluetoothctl disconnect';

# make it easy to adjust brightness
alias keyboard.backlight.off='sudo tee /sys/class/leds/dell::kbd_backlight/brightness <<< 0'
alias keyboard.backlight.dim='sudo tee /sys/class/leds/dell::kbd_backlight/brightness <<< 1'
alias keyboard.backlight.bright='sudo tee /sys/class/leds/dell::kbd_backlight/brightness <<< 2'

# make it easy to fetch the weather
alias weather.in.here='curl wttr.in'
alias weather.in.indianapolis='curl wttr.in/Indianapolis'
