#!/usr/bin/env bash
######################################################################
# .what = declare the auto-lock timer, because COSMIC gives 1password no idle
#         signal to lock itself on
# .ref  = https://1password.community/discussion/121078
#
# ⚠️ .a systemd timer stands in for a feature the app already has
#   - 1password locks itself after N idle minutes, given an idle signal
#   - COSMIC raises none, so the toggle reads on and does no work
#   - ⇒ the lock is driven from outside, on a wall clock
#
# ⚠️ .the 5-minute lock is NOT softened for convenience
#   - `1.2.power` disables every idle path on this box on purpose
#   - ⇒ this is the ONLY guard between an unattended laptop and an open vault
#
# .a USER timer, not a system one
#   - `1password --lock` speaks to the live app on that session's bus
#   - a system unit fires as root, where there is no app to lock
#
# ⚠️ .`daemon-reload` before `enable --now`
#   - systemd caches unit files, so a rewrite alone leaves the OLD one live
#
# guarantee
#   - idempotent: both units are declared from this file's text
#   - `enable --now` converges on an already-enabled timer
######################################################################

grove_provision_6_5_onepassword_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no vault on $GROVE_ENV_SERVER, so no lock timer is owed"
    return 0
  fi

  ####################################################################
  # 0. the app the timer drives — without it the timer fires into no one
  ####################################################################
  if ! command -v 1password >/dev/null 2>&1; then
    echo "   ✋ the 1password app is absent, so a lock timer has no vault to lock" >&2
    echo "      ⇒ this bundle's provision phase installs it BEFORE this phase runs," >&2
    echo "        so an absent app here means that phase reported a pass it did" >&2
    echo "        not earn (rule.forbid.failhide)" >&2
    echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
    echo "             --include onepassword" >&2
    return 1
  fi

  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$unit_dir" || return 1

  ####################################################################
  # 1. the two units, each declared whole
  #
  #   - the ExecStart path is absolute, because a unit inherits no login PATH
  #   - a bare `1password` resolves for a human at a shell and for no unit
  ####################################################################
  cat > "$unit_dir/1password-lock.service" <<'EOF'
[Unit]
Description=Lock 1Password

[Service]
Type=oneshot
ExecStart=/usr/bin/1password --lock
EOF

  cat > "$unit_dir/1password-lock.timer" <<'EOF'
[Unit]
Description=Lock 1Password every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF
  echo "   • lock units declared (1password-lock.service + .timer)"

  ####################################################################
  # 2. reload FIRST — see the header for why a rewrite alone does no work
  ####################################################################
  systemctl --user daemon-reload || {
    echo "   ✋ systemctl --user daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay" >&2
    echo "        live, so the fix appears applied and the box does not change" >&2
    return 1
  }

  if systemctl --user enable --now 1password-lock.timer; then
    echo "   • 1password-lock.timer enabled and started"
  else
    echo "   ✋ could not enable 1password-lock.timer" >&2
    echo "      ⇒ the vault then never auto-locks: COSMIC raises no idle signal," >&2
    echo "        and 1.2.power disables every other idle path on this box, so" >&2
    echo "        an unattended laptop keeps an open vault indefinitely" >&2
    return 1
  fi

  ####################################################################
  # 3. the ONE step no installer may take for a human
  #
  #   - the cli integration is a toggle inside the app's settings, reached by click
  #   - 🛑 every phase must COMPLETE unattended, so it is printed, never attempted
  #   - (rule.require.one-command-provision)
  ####################################################################
  echo "   🌙 one step is a human's: 1password → settings → developer →"
  echo "      enable 'integrate with 1password cli'"
  echo "      ⇒ until then op works but cannot borrow the desktop app's session,"
  echo "        so every op call asks for the account password by hand"
}
