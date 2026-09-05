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

grove_provision_1_2_power_configure_upsert() {
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
  # start each login in the battery power profile
  #
  # ⚠️ .why a power line lives in this bundle at all
  #   - `system76-power` is pop-os's own governor and applies to this laptop
  #   - it is the one power concern a login shell owns rather than logind
  #
  # 🛑 write it with a heredoc, never `echo '\n…'`
  #   - bash's `echo` does NOT expand `\n` inside single quotes
  #   - ⇒ `echo '\n# x\nsystem76-power profile battery' >> ~/.profile` writes ONE literal line
  #   - `~/.profile` then gains a line the shell cannot run
  #   - and a `grep -qxF` guard never matches that mangled line
  #   - ⇒ every run appends another copy
  #   - the guard looks like idempotence and delivers the opposite
  #
  # .why it is gated on the binary
  #   - `system76-power` ships with pop-os only
  #   - on another debian box the line prints "command not found" before every prompt
  #   - `2.7.aliases` guards its sourced files against the same class of defect
  ####################################################################
  # 🛑 the guard greps a SLUG MARKER, never the command it writes
  #   - a guard coupled to the COMMAND breaks on any edit to that command
  #   - ⇒ it stops matching a healthy file, and every run appends another copy
  #   - a `# grove: <slug>` marker couples the guard to the CLAIM, which is stable
  #   - `5.1.node` uses this same shape on this same file
  #
  # ⚠️ keep the LEGACY content phrase beside the marker
  #   - an extant box holds the pre-marker block
  #   - 📜 2026-09-02: the fence word moved `# devenv:` → `# grove:`, so old boxes MISS `$profile_mark`
  #   - `$profile_legacy` matches the CONTENT line, which neither change touched
  #   - ⇒ an old box lands on the elif and is left alone, not handed a SECOND battery line
  #   - it may be dropped only once no box predates the FENCE RENAME
  if command -v system76-power >/dev/null 2>&1; then
    local profile_dst="$HOME/.profile"
    local profile_mark="# grove: start each login in the battery power profile"
    local profile_legacy="system76-power profile battery"

    if grep -qF "$profile_mark" "$profile_dst" 2>/dev/null; then
      echo "   • battery profile already declared in ~/.profile"
    elif grep -qF "$profile_legacy" "$profile_dst" 2>/dev/null; then
      echo "   • battery profile already declared (pre-marker block; left as is)"
    else
      cat >> "$profile_dst" <<'EOF'

# grove: start each login in the battery power profile (pop-os / system76-power)
command -v system76-power >/dev/null 2>&1 && system76-power profile battery >/dev/null 2>&1
EOF
      echo "   • battery profile declared in ~/.profile"
    fi
  else
    echo "   🌙 system76-power is absent, so no battery profile is declared"
    echo "      — it ships with pop-os; on another distro this is expected"
  fi

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
}
