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
  ## disable all automatic suspend/sleep/lock
  ## ref: .agent/repo=.this/role=any/briefs/system.power.spec.md
  ######################

  # configure logind (hardware keys + lid)
  local LOGIND_CONF="/etc/systemd/logind.conf"
  if grep -q '^HandlePowerKey=ignore' "$LOGIND_CONF" && grep -q '^IdleAction=ignore' "$LOGIND_CONF"; then
    echo "• logind already configured"
  else
    # remove any extant entries (commented or not)
    for key in HandlePowerKey HandleSuspendKey HandleHibernateKey HandleRebootKey HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked IdleAction IdleActionSec; do
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

# never idle-lock
IdleAction=ignore
IdleActionSec=infinity
EOF
    echo "• logind configured"
  fi

  # configure sleep (disable suspend/hibernate system-wide)
  local SLEEP_CONF="/etc/systemd/sleep.conf"
  if grep -q '^AllowSuspend=no' "$SLEEP_CONF" 2>/dev/null; then
    echo "• sleep already configured"
  else
    # remove any extant entries (commented or not)
    for key in AllowSuspend AllowHibernation AllowSuspendThenHibernate AllowHybridSleep; do
        sudo sed -i "/^#*${key}=/d" "$SLEEP_CONF" 2>/dev/null || true
    done

    # ensure [Sleep] section exists
    if ! grep -q '^\[Sleep\]' "$SLEEP_CONF" 2>/dev/null; then
      echo "[Sleep]" | sudo tee "$SLEEP_CONF" > /dev/null
    fi

    sudo tee -a "$SLEEP_CONF" > /dev/null <<'EOF'

# disable all sleep modes; use terminal for explicit suspend
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
    echo "• sleep configured"
  fi

  echo "run 'machine.logout' or 'machine.reboot' to apply"
}
