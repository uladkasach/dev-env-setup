#!/usr/bin/env bash
######################################################################
# pt1a: system keybinds
# keyd, keynav, logind, altswap reset
######################################################################

install_keyd() {
  sudo add-apt-repository -y ppa:keyd-team/ppa
  sudo apt-get update
  sudo apt-get install -y keyd
  # symlink keyd.rvaiya -> keyd for convenience
  sudo ln -sf /usr/bin/keyd.rvaiya /usr/bin/keyd
  sudo systemctl enable --now keyd
}

configure_keyd() {
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

install_keynav() {
  #########################
  ## ref: https://www.semicomplete.com/projects/keynav/
  ##
  ## notes
  ##  - `ctrl` + `;` -> begin keynav selection
  ##  - `h`, `i`, `j`, `l` -> select the part of the screen
  ##  - `shift` + `h`,`i`,`j`,`k` -> change the last selection you made to the new key
  ##  - `space` -> click on selection
  ##  - `semicolon` -> move to the selection
  #########################
  sudo apt-get install keynav
  grep -qF '(keynav && echo "keynav started"' ~/.profile || cat <<'EOF' >> ~/.profile

# start keynav in background
(keynav && echo "keynav started" || echo "keynav already running") &
EOF
}

configure_logind() {
  ######################
  ## dont suspend on lid close
  ## ref: https://ubuntuhandbook.org/index.php/2020/05/lid-close-behavior-ubuntu-20-04/
  ######################
  LOGIND_CONF="/etc/systemd/logind.conf"

  # skip if already configured
  if grep -q '^HandlePowerKey=ignore' "$LOGIND_CONF"; then
    echo "• logind already configured; skipped"
    return 0
  fi

  # remove any extant entries (commented or not)
  for key in HandlePowerKey HandleSuspendKey HandleHibernateKey HandleRebootKey HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked; do
      sudo sed -i "/^#*${key}=/d" "$LOGIND_CONF"
  done

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
  echo "run 'machine.logout' or 'machine.reboot' to apply"
}
