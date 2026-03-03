#!/usr/bin/env bash
######################################################################
# pt7: legacy/gnome (deprecated — cosmic replaces these)
######################################################################

install_gnome_extensions() {
  sudo apt install lm-sensors gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 gnome-system-monitor && echo 'install the system monitor extension through website for now...' && browser https://extensions.gnome.org/extension/3010/system-monitor-next/
  sudo apt install -y gir1.2-gst-plugins-base-1.0 && echo 'install the radio extension through website for now...' && browser https://extensions.gnome.org/extension/836/internet-radio/
  sudo apt install -y gnome-shell-pomodoro
  logout
}

configure_battery_saver() {
  grep -qxF 'system76-power profile battery' ~/.profile || echo '\n# start in battery saver\nsystem76-power profile battery' >> ~/.profile
}

configure_nightlight() {
  gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
}

configure_brightness() {
  gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false
}

configure_screenshot_shortcuts() {
  gsettings set org.gnome.shell.keybindings show-screenshot-ui "['Print', '<Primary><Shift><Alt>P']"
  gsettings set org.gnome.shell.keybindings show-screen-recording-ui "['<Ctrl><Shift><Alt>R']"
}
