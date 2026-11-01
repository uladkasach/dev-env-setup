#!/usr/bin/env bash
######################################################################
# .what = declare `logind.conf` and `sleep.conf` so no path leads to a suspend
#
# .why TWO files, neither redundant
#   - `logind.conf` answers what happens WHEN a trigger fires (a key, a lid, idle)
#   - `sleep.conf` answers whether the suspend/hibernate act is ALLOWED at all
#   - logind alone leaves `systemctl suspend` and every desktop menu item live
#   - sleep.conf alone leaves the lid switch free to try, and the session still locks on the way
#
# .why every key is DELETED before it is appended
#   - both files ship with the keys present-but-commented
#   - systemd reads the LAST assignment of a key
#   - ⇒ an append alone makes the outcome a function of what a past revision wrote
#   - `sed -i '/^#*key=/d'` strips the commented AND uncommented forms first
#   - (rule.require.judge-declared-state-not-live-state)
#
# .why the early-return grep tests exactly TWO keys
#   - `HandlePowerKey` is the first key the block declares and `IdleAction` is the last
#   - ⇒ both present means the whole block landed
#   - a test of one would pass on a half-written file from an interrupted run
#
# .why sleep.conf gets a `[Sleep]` header check that logind.conf does not
#   - `logind.conf` always ships with its `[Login]` section
#   - `sleep.conf` can be absent entirely on a minimal image
#   - an append with no section header puts the keys in no section
#   - ⇒ systemd ignores them silently, and a `cat` still reads correct
#
# guarantee:
#   - idempotent: each half short-circuits when its declaration is already present
#   - idempotent: otherwise it strips-then-declares, so a re-run converges to this text
######################################################################

######################################################################
# .what = the power profile follows the charger, by a user unit that watches it
#           - charger connected and battery at or past 80% → performance
#           - charger disconnected                         → battery
#         (`machine_power_profile_sync` holds the rule and says why edges, never a level)
#
# .why a USER unit
#   - `system76-power profile` asks the daemon over dbus as the session user, so no root
#   - the zone it acts on lives in `$XDG_RUNTIME_DIR`, which only a user manager provides
#
# 🛑 .why the old `~/.profile` line is REMOVED, not kept beside the unit
#   - it set `battery` at every login shell, and a terminal can open a login shell
#   - ⇒ on the charger at 100%, each new terminal flipped the box back to battery-saver,
#     the very undo the watch exists to prevent — two writers on one setting
#     (`rule.forbid.two-writers-on-one-artifact`)
#   - the unit covers what the line did: a session that starts off the charger enters the
#     `battery` zone on its first read, and sets it
#   - both shapes are removed: the `# grove:` marked block, and the pre-marker bare line
#
# .why a decline on a box with no battery
#   - a battery is a physical fact; a desktop or a cloud grove has no charger edge, ever
#   - ⇒ no unit is armed there, and `--watch` itself exits clean if one ever is
######################################################################
grove_provision_1_2_power_profile_sync() {
  local profile_dst="$HOME/.profile"
  if [[ -f "$profile_dst" ]] && grep -qE 'system76-power profile battery|^# (grove|devenv): start each login in the battery power profile' "$profile_dst"; then
    sed -i -E '/^# (grove|devenv): start each login in the battery power profile/d; /system76-power profile battery/d' "$profile_dst" || return 1
    echo "   • the login-shell battery line is removed from ~/.profile — the unit owns the profile now"
  fi

  if ! command -v system76-power >/dev/null 2>&1; then
    echo "   🌙 system76-power is absent, so no profile follows the charger"
    echo "      — it ships with pop-os; on another distro this is expected"
    return 0
  fi
  local d has_battery=0
  for d in /sys/class/power_supply/*; do
    [[ -r "$d/type" && "$(<"$d/type")" == Battery ]] && has_battery=1
  done
  if (( ! has_battery )); then
    echo "   🌙 no battery on this box, so no profile follows a charger"
    return 0
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "   🌙 the profile watch is declined — no user manager answers here"
    echo "      run it by hand: machine_power_profile_sync --mode apply"
    return 0
  fi

  local bin_dir="$HOME/.local/bin" unit_dir="$HOME/.config/systemd/user"
  local unit=machine_power_profile_sync.service
  local name
  for name in machine_power_profile_sync "$unit"; do
    [[ -f "$GROVE_SRC/machine/$name" ]] || { echo "   ✋ no $name at $GROVE_SRC/machine/$name" >&2; return 1; }
  done
  mkdir -p "$bin_dir" "$unit_dir" || return 1
  cp "$GROVE_SRC/machine/machine_power_profile_sync" "$bin_dir/" && chmod +x "$bin_dir/machine_power_profile_sync" || return 1
  cp "$GROVE_SRC/machine/$unit" "$unit_dir/$unit" || return 1

  # ⚠️ daemon-reload, then RESTART — not only enable --now. a unit already active keeps the
  #   old executable in memory, so a rewrite with no restart leaves the old rule live
  systemctl --user daemon-reload || { echo "   ✋ systemctl --user daemon-reload failed" >&2; return 1; }
  if systemctl --user enable "$unit" >/dev/null 2>&1 && systemctl --user restart "$unit"; then
    echo "   • $unit armed — the profile now follows the charger"
  else
    echo "   ✋ could not arm $unit" >&2
    echo "      ⇒ the profile stays wherever it was last set, plug or no plug" >&2
    echo "      read why: journalctl --user -u $unit -n 20" >&2
    return 1
  fi
}

grove_provision_1_2_power_configure_upsert() {
  local failed=0
  ####################################################################
  # logind — what happens when a trigger fires
  ####################################################################
  local logind_conf="/etc/systemd/logind.conf"
  if grep -q '^HandlePowerKey=ignore' "$logind_conf" 2>/dev/null \
    && grep -q '^IdleAction=ignore' "$logind_conf" 2>/dev/null; then
    echo "   • logind already declared"
  elif ! bundle.root.owns "the logind power declaration" \
    "$logind_conf does not declare HandlePowerKey=ignore"; then
    # ⚠️ the decline is its OWN branch, never a `|| return 0`
    #   - a return would skip the `~/.profile` half at the foot of this body
    #   - that half is per-seat and needs no privilege
    #   - 📜 `4.5.nvim` lost exactly that capability when a root check guarded work that wanted none
    #   - ⇒ this branch ends the LOGIND half alone and the body carries on
    :
  else
    # ⚠️ the guard sits in a branch, not at the function top
    #   - a converged box takes the first branch and spends no root
    #   - ⇒ a top-of-body assert would halt a run with no work to do
    #   - that is a ✋ on a box already correct (rule.require.identical-bundle-composition)
    local key
    for key in HandlePowerKey HandleSuspendKey HandleHibernateKey HandleRebootKey \
               HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked \
               IdleAction IdleActionSec; do
      sudo sed -i "/^#*${key}=/d" "$logind_conf"
    done

    sudo tee -a "$logind_conf" >/dev/null <<'EOF'

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
    echo "   • logind declared"
  fi

  ####################################################################
  # sleep — whether the act is allowed at all
  ####################################################################
  local sleep_conf="/etc/systemd/sleep.conf"
  if grep -q '^AllowSuspend=no' "$sleep_conf" 2>/dev/null; then
    echo "   • sleep already declared"
  elif ! bundle.root.owns "the sleep declaration" \
    "$sleep_conf does not declare AllowSuspend=no"; then
    # see the logind half above for why a decline gets its own branch
    :
  else
    local key
    for key in AllowSuspend AllowHibernation AllowSuspendThenHibernate AllowHybridSleep; do
      sudo sed -i "/^#*${key}=/d" "$sleep_conf" 2>/dev/null || true
    done

    # the section header must exist, or systemd ignores the keys silently
    if ! grep -q '^\[Sleep\]' "$sleep_conf" 2>/dev/null; then
      echo "[Sleep]" | sudo tee "$sleep_conf" >/dev/null
    fi

    sudo tee -a "$sleep_conf" >/dev/null <<'EOF'

# disable all sleep modes; use terminal for explicit suspend
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
    echo "   • sleep declared"
  fi

  ####################################################################
  # the power PROFILE follows the charger — see `grove_provision_1_2_power_profile_sync`
  ####################################################################
  grove_provision_1_2_power_profile_sync || failed=1

  ####################################################################
  # .note = logind re-reads its config at start, so these take on the next login
  #   - no restart is issued here on purpose
  #   - `systemctl restart systemd-logind` terminates the live graphical session
  #   - ⇒ an upgrade run would destroy the desktop it was launched from
  ####################################################################
  # ⚠️ `power.restart`, never `machine.reboot` — that verb was a synonym with a
  #    silent cost, and it was THIS line that recommended it. `power.restart`
  #    snaps the kitty window/pwd map first, and a reboot a human is told to run
  #    is exactly the reboot known in advance
  echo "   🌙 awaits a session restart — run 'machine.logout' or 'power.restart'"
  echo "      to apply. no restart is issued here: a logind restart kills the live"
  echo "      graphical session, and this run was launched from inside it"
  return $failed
}
