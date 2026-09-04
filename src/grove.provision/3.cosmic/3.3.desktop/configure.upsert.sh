#!/usr/bin/env bash
######################################################################
# .what = declare COSMIC's shell layout — keybinds, terminal action, panel,
#         autotile, idle timers
#
# .every write is a DECLARED file, never an append or an edit-in-place
#   - COSMIC reads plain files under ~/.config/cosmic/
#   - a full rewrite is idempotent by construction
#   - (rule.require.idempotent-install-procedures)
#
# ⚠️ .system_actions is DERIVED from the system copy, never declared
#   - COSMIC ships a full action table and adds entries between releases
#   - to declare it whole would freeze this box at the table of the day written
#   - so the system copy is read, and only four lines are substituted
#
# guarantee
#   - idempotent: every file is rewritten from a declared source
#   - it DECLINES where no compositor exists
######################################################################

grove_provision_3_3_desktop_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — these are compositor settings, and"
    echo "      $GROVE_ENV_SERVER runs no compositor to read them"
    return 0
  fi

  ####################################################################
  # 1. the custom keybinds
  ####################################################################
  local shortcuts_dir="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"
  mkdir -p "$shortcuts_dir" || return 1

  cat > "$shortcuts_dir/custom" <<'SHORTCUTS'
{
    (modifiers: [Super]): System(WorkspaceOverview),
    (modifiers: [Super], key: "slash"): System(Launcher),
    (modifiers: [], key: "Print"): System(Screenshot),
    (modifiers: [Ctrl, Shift, Alt], key: "p"): System(Screenshot),
}
SHORTCUTS
  echo "   • keybinds: super → overview, super+/ → search, Print → screenshot"

  ####################################################################
  # 2. the system actions — kitty as the terminal, power keys disarmed
  #
  #   - the header says why this one is derived rather than declared
  #
  # 🛑 .LockScreen is NOT in the disarm list, and must never be added
  #   - the other three END A SESSION, so a stray press costs unsaved work
  #   - a lock costs a password, so the disarm argument does not reach it
  #   - ⚠️ to disarm it left a box that could not be locked by any means
  #   - `system.power.spec` listed a lock among its explicit commands throughout
  ####################################################################
  local system_actions="/usr/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions"
  local user_actions="$shortcuts_dir/system_actions"

  if [[ -f "$system_actions" ]]; then
    sed -e 's|Terminal: "cosmic-term"|Terminal: "sh -c '"'"'exec kitty --directory ~ 2>/dev/null'"'"'"|' \
        -e 's|PowerOff: "cosmic-osd shutdown"|PowerOff: "true"|' \
        -e 's|Suspend: "systemctl suspend"|Suspend: "true"|' \
        -e 's|LogOut: "cosmic-osd log-out"|LogOut: "true"|' \
        "$system_actions" > "$user_actions" || return 1
    echo "   • default terminal: kitty; power/logout keys disarmed, lock ARMED"
  else
    echo "   🌙 no system action table at $system_actions, so the terminal and"
    echo "      power overrides were not applied"
  fi

  ####################################################################
  # 3. the bottom dock — off
  ####################################################################
  local panel_dir="$HOME/.config/cosmic/com.system76.CosmicPanel/v1"
  mkdir -p "$panel_dir" || return 1
  printf '[\n    "Panel",\n]\n' > "$panel_dir/entries" || return 1
  echo "   • dock disabled"

  ####################################################################
  # 4. autotile, globally
  ####################################################################
  local comp_dir="$HOME/.config/cosmic/com.system76.CosmicComp/v1"
  mkdir -p "$comp_dir" || return 1
  echo "true"   > "$comp_dir/autotile"          || return 1
  echo "Global" > "$comp_dir/autotile_behavior" || return 1
  echo "   • autotile on, for every workspace"

  ####################################################################
  # 5. the idle timers — off
  #
  #   - a long build or a detached grove run is not idleness
  #   - a screen that sleeps mid-run costs the session it was meant to show
  ####################################################################
  local idle_dir="$HOME/.config/cosmic/com.system76.CosmicIdle/v1"
  mkdir -p "$idle_dir" || return 1
  echo "None" > "$idle_dir/screen_off_time"         || return 1
  echo "None" > "$idle_dir/suspend_on_ac_time"      || return 1
  echo "None" > "$idle_dir/suspend_on_battery_time" || return 1
  echo "   • idle screen-off and suspend disabled"

  ####################################################################
  # 6. the top panel — status area left, controls right
  ####################################################################
  local top_panel_dir="$HOME/.config/cosmic/com.system76.CosmicPanel.Panel/v1"
  mkdir -p "$top_panel_dir" || return 1
  cat > "$top_panel_dir/plugins_wings" <<'WINGS'
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
  echo "   • top panel: status area left, controls right"
}
