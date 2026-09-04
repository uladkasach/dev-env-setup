#!/usr/bin/env bash
######################################################################
# .what = prove COSMIC's shell layout is declared the way this repo says
#
# ⚠️ .the terminal action earns its own claim
#   - a renamed key or a moved system table makes the kitty substitution miss
#   - the file still writes, still parses, and opens the WRONG terminal
#
# ⚠️ .the upsert writes SIX surfaces, and this asks all six
#   - the dock and the applet list are COSMIC's OWN to rewrite on upgrade
#   - an upsert whose writes outnumber its claims reports on part of itself
#   - (rule.require.upgrade-entries-verify-themselves)
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_3_3_desktop_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no compositor on $GROVE_ENV_SERVER to read these"
    return 0
  fi

  local failed=0
  local shortcuts_dir="$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1"

  ####################################################################
  # 1. the custom keybinds hold the launcher entry
  ####################################################################
  if [[ -r "$shortcuts_dir/custom" ]] \
    && grep -F 'System(Launcher)' "$shortcuts_dir/custom" >/dev/null; then
    echo "   • the custom keybinds are declared ✔"
  else
    echo "   ✋ the custom keybinds are ABSENT or incomplete" >&2
    echo "      ⇒ super+/ opens no launcher and super opens no overview, so the" >&2
    echo "        two gestures used most on this desktop do no work" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. the terminal action names kitty — see the header
  ####################################################################
  local actions="$shortcuts_dir/system_actions"
  if [[ ! -r "$actions" ]]; then
    echo "   ✋ no system action override at $actions" >&2
    echo "      ⇒ COSMIC's terminal keybind opens cosmic-term, and the power," >&2
    echo "        lock and logout keys are live beside the keys in daily use" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  elif grep -F 'kitty' "$actions" >/dev/null; then
    echo "   • COSMIC's terminal action opens kitty ✔"
  else
    echo "   ✋ $actions exists but its Terminal action does NOT name kitty" >&2
    echo "      ⇒ the substitution missed, so the file writes, parses, and opens" >&2
    echo "        a terminal — just the wrong one. a presence check passes here" >&2
    echo "      read it: grep Terminal $actions" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2b. LockScreen is ARMED — the one action the disarm must never reach
  #
  # 🛑 .why a claim of its own, beside the terminal claim above
  #   - the other three actions read `true` BY DESIGN, so no blanket check fits
  #   - 📜 it WAS disarmed, and no check here saw it
  #   - the cost was a laptop that could not be locked, on the box that holds the rack
  ####################################################################
  if [[ -r "$actions" ]]; then
    if grep -F 'LockScreen: "loginctl lock-session"' "$actions" >/dev/null; then
      echo "   • the LockScreen action is ARMED ✔"
    else
      echo "   ✋ COSMIC's LockScreen action is NOT armed" >&2
      echo "      ⇒ the idle timers are off by design, so a deliberate lock is the" >&2
      echo "        ONLY lock this box has — and this is one of its two routes" >&2
      echo "      ⇒ do NOT 'fix' this by a disarm to match PowerOff/Suspend/LogOut:" >&2
      echo "        those end a session, this costs a password. the argument that" >&2
      echo "        disarms them does not reach this one" >&2
      echo "      read it: grep LockScreen $actions" >&2
      echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
      failed=1
    fi
  fi

  ####################################################################
  # 3. autotile is on
  ####################################################################
  local autotile="$HOME/.config/cosmic/com.system76.CosmicComp/v1/autotile"
  if [[ -r "$autotile" ]] && [[ "$(cat "$autotile" 2>/dev/null)" == "true" ]]; then
    echo "   • autotile is on ✔"
  else
    echo "   ✋ autotile is off or undeclared" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 4. the idle timers are off
  #
  #   - all three, because a box that disables screen-off alone still SUSPENDS
  #   - a mid-run suspend is the more costly of the two
  ####################################################################
  local idle_dir="$HOME/.config/cosmic/com.system76.CosmicIdle/v1"
  local live=0 want=3
  local key
  for key in screen_off_time suspend_on_ac_time suspend_on_battery_time; do
    [[ -r "$idle_dir/$key" ]] && [[ "$(cat "$idle_dir/$key" 2>/dev/null)" == "None" ]] \
      && live=$(( live + 1 ))
  done

  if [[ "$live" -eq "$want" ]]; then
    echo "   • all $want idle timers are disabled ✔"
  else
    echo "   ✋ only $live of $want idle timers are disabled" >&2
    echo "      ⇒ a box that disables screen-off alone still SUSPENDS mid-run," >&2
    echo "        which kills a long build or a detached grove session" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 5. the bottom dock stays off
  #
  # ⚠️ .the one most apt to regress
  #   - COSMIC owns and rewrites `entries`, so a toggle or an upgrade re-adds "Dock"
  #   - (rule.require.upgrade-entries-verify-themselves)
  ####################################################################
  local entries="$HOME/.config/cosmic/com.system76.CosmicPanel/v1/entries"
  if [[ ! -r "$entries" ]]; then
    echo "   ✋ no panel entry table at $entries" >&2
    echo "      ⇒ COSMIC falls back to its own default, which ships the bottom" >&2
    echo "        dock enabled" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  elif grep -F 'Dock' "$entries" >/dev/null 2>&1; then
    echo "   ✋ the bottom dock is BACK — $entries names it" >&2
    echo "      ⇒ COSMIC owns this file and rewrites it, so a settings toggle or" >&2
    echo "        an upgrade re-adds 'Dock' with no other check to catch it" >&2
    echo "      read it: cat $entries" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  elif grep -F '"Panel"' "$entries" >/dev/null 2>&1; then
    echo "   • the bottom dock is off, and the top panel is declared ✔"
  else
    echo "   ✋ $entries names no \"Panel\" at all" >&2
    echo "      ⇒ the top panel itself is gone, so the status area, the clock, and" >&2
    echo "        every applet claim 6 checks have nowhere to render" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 6. the top panel carries the declared applets, and NOT the two removed
  #
  # ⚠️ .the ABSENCE half carries the weight
  #   - this surface exists to remove the workspaces and app-launcher buttons
  #   - ⇒ it asks both: the eight ARE there, and the two are NOT
  ####################################################################
  local wings="$HOME/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"
  if [[ ! -r "$wings" ]]; then
    echo "   ✋ no panel applet table at $wings" >&2
    echo "      ⇒ COSMIC seeds its own, which puts the workspaces and app-launcher" >&2
    echo "        buttons back on the panel" >&2
    echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
    failed=1
  else
    # the applet ids are COSMIC's own, so they are not ours to choose
    local applet applet_absent=()
    for applet in StatusArea Tiling Audio Bluetooth Network Battery Notifications Power; do
      grep -F "com.system76.CosmicApplet$applet" "$wings" >/dev/null 2>&1 \
        || applet_absent+=("$applet")
    done

    local unwanted unwanted_live=()
    for unwanted in Workspaces AppLauncher; do
      grep -F "com.system76.CosmicApplet$unwanted" "$wings" >/dev/null 2>&1 \
        && unwanted_live+=("$unwanted")
    done

    if [[ "${#applet_absent[@]}" -eq 0 && "${#unwanted_live[@]}" -eq 0 ]]; then
      echo "   • the top panel carries all 8 declared applets, and neither removed one ✔"
    else
      [[ "${#applet_absent[@]}" -gt 0 ]] && {
        echo "   ✋ the top panel lacks applets: ${applet_absent[*]}" >&2
        echo "      ⇒ each one is a control this desktop reaches for by click —" >&2
        echo "        audio, network, battery — with no other surface that shows it" >&2
      }
      [[ "${#unwanted_live[@]}" -gt 0 ]] && {
        echo "   ✋ the top panel carries applets this bundle removes: ${unwanted_live[*]}" >&2
        echo "      ⇒ COSMIC re-seeds a config it owns on upgrade, so these return" >&2
        echo "        on their own" >&2
      }
      echo "      read it: cat $wings" >&2
      echo "      fix: rhx grove.provision --what 3.3.desktop --mode apply" >&2
      failed=1
    fi
  fi

  return $failed
}
