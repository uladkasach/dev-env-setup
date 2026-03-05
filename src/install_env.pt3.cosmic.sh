#!/usr/bin/env bash
######################################################################
# pt3: cosmic desktop
# cosmic-term, cosmic theme, cosmic desktop (keybinds, panels, dock)
######################################################################

upgrade_cosmic_term() {
  # ensure cosmic-term >= 1.0.5 (configurable keybindings)
  local version
  version=$(cosmic-term --version 2>/dev/null | grep -oP '[\d.]+')
  if dpkg --compare-versions "${version:-0}" lt "1.0.5"; then
    sudo apt update && sudo apt install -y cosmic-term
    echo "• cosmic-term upgraded to $(cosmic-term --version 2>/dev/null)"
  else
    echo "• cosmic-term ${version} already meets minimum (1.0.5)"
  fi
}

configure_cosmic_term() {
  # ctrl+\ = new window
  local config_dir="$HOME/.config/cosmic/com.system76.CosmicTerm/v1"
  mkdir -p "$config_dir"
  cat > "$config_dir/shortcuts_custom" << 'EOF'
{
    (
        modifiers: [
            Ctrl,
        ],
        key: "\\",
    ): WindowNew,
}
EOF
  echo "• cosmic-term keybinds configured"
}

configure_cosmic_theme() {
  cosmic-settings appearance import "$HOME/git/more/dev-env-setup/src/cosmic.theme.ron"
  echo "• cosmic desert theme applied"

  # apply desert colors to GTK3/GTK4 apps (firefox, etc)
  local gtk4_dir="$HOME/.config/gtk-4.0/cosmic"
  local gtk3_dir="$HOME/.config/gtk-3.0"
  mkdir -p "$gtk4_dir" "$gtk3_dir"
  cp "$HOME/git/more/dev-env-setup/src/cosmic.gtk.desert.css" "$gtk4_dir/dark.css"
  ln -sf "$gtk4_dir/dark.css" "$gtk3_dir/gtk.css"
  echo "• GTK desert theme applied (restart GTK apps to see changes)"
}

configure_cosmic_desktop() {
  local shortcuts_dir="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
  mkdir -p "$shortcuts_dir"

  # custom keybinds: super → overview, super+/ → launcher, screenshot shortcuts
  cat > "$shortcuts_dir/custom" << 'SHORTCUTS'
{
    (modifiers: [Super]): System(WorkspaceOverview),
    (modifiers: [Super], key: "slash"): System(Launcher),
    (modifiers: [], key: "Print"): System(Screenshot),
    (modifiers: [Ctrl, Shift, Alt], key: "p"): System(Screenshot),
}
SHORTCUTS
  echo "• keybinds: super → overview, super+/ → search, Print/ctrl+shift+alt+p → screenshot"

  # override system_actions: ptyxis terminal + disable power/lock/logout keybinds
  local system_actions="/usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions"
  local user_actions="$shortcuts_dir/system_actions"
  if [[ -f "$system_actions" ]]; then
    sed -e 's|Terminal: "cosmic-term"|Terminal: "flatpak run app.devsuite.Ptyxis --new-window -d ~"|' \
        -e 's|PowerOff: "cosmic-osd shutdown"|PowerOff: "true"|' \
        -e 's|Suspend: "systemctl suspend"|Suspend: "true"|' \
        -e 's|LogOut: "cosmic-osd log-out"|LogOut: "true"|' \
        -e 's|LockScreen: "loginctl lock-session"|LockScreen: "true"|' \
        "$system_actions" > "$user_actions"
    echo "• default terminal: ptyxis"
    echo "• power/lock/logout keybinds disabled (use terminal commands)"
  fi

  # disable bottom dock
  local panel_dir="$HOME/.config/cosmic/com.system76.CosmicPanel/v1"
  mkdir -p "$panel_dir"
  cat > "$panel_dir/entries" << 'ENTRIES'
[
    "Panel",
]
ENTRIES
  echo "• dock disabled"

  # enable tiling by default (all workspaces start tiled)
  local comp_dir="$HOME/.config/cosmic/com.system76.CosmicComp/v1"
  mkdir -p "$comp_dir"
  echo "true" > "$comp_dir/autotile"
  echo "Global" > "$comp_dir/autotile_behavior"
  echo "• tiling enabled globally (all workspaces tiled by default)"

  # disable screen timeout (never turn off on idle timer)
  local idle_dir="$HOME/.config/cosmic/com.system76.CosmicIdle/v1"
  mkdir -p "$idle_dir"
  echo "None" > "$idle_dir/screen_off_time"
  echo "None" > "$idle_dir/suspend_on_ac_time"
  echo "None" > "$idle_dir/suspend_on_battery_time"
  echo "• screen timeout disabled (never turns off on idle)"

  # remove workspaces/applications buttons from top panel
  local top_panel_dir="$HOME/.config/cosmic/com.system76.CosmicPanel.Panel/v1"
  mkdir -p "$top_panel_dir"
  cat > "$top_panel_dir/plugins_wings" << 'WINGS'
Some(([
    "com.system76.CosmicAppletStatusArea",
], [
    "com.system76.CosmicAppletTiling",
    "com.system76.CosmicAppletAudio",
    "com.system76.CosmicAppletBluetooth",
    "com.system76.CosmicAppletNetwork",
    "com.system76.CosmicAppletBattery",
    "com.system76.CosmicAppletNotifications",
    "com.system76.CosmicAppletPower",
]))
WINGS
  echo "• top panel: status area left, controls right"
}
