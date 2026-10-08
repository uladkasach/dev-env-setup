#!/usr/bin/env bash
######################################################################
# .what = prove the user manager revives itself, and answers on its bus NOW
#
# ⚠️ .why three claims, each read separately
#   - the drop-in on disk says what was declared
#   - `systemctl show -p Restart` says what systemd LOADED; a file unread by a
#     daemon-reload is policy no process obeys
#   - `systemctl --user show-environment` says the manager ANSWERS. a unit can
#     read active while its bus refuses, and the bus is what callers need
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_1_6_5_usermanager_configure_verify() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.6.procs/1.6.5.usermanager/user@.revive.conf"
  local live="$GROVE_USERMANAGER_DROPIN"
  local unit="user@$(id -u).service"
  local failed=0

  if cmp -s "$declared" "$live"; then
    echo "   • $live matches the declared revive drop-in ✔"
  else
    echo "   ✋ $live differs from the declared revive drop-in" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 1.6.5.usermanager --mode apply" >&2
    failed=1
  fi

  local restart
  restart="$(systemctl show -p Restart --value "$unit" 2>/dev/null)"
  if [[ "$restart" == "always" ]]; then
    echo "   • $unit is loaded with Restart=always ✔"
  else
    echo "   ✋ $unit is loaded with Restart='${restart:-unknown}'" >&2
    echo "      ⇒ a killed user manager stays dead until a re-login" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 1.6.5.usermanager --mode apply" >&2
    failed=1
  fi

  if systemctl --user show-environment >/dev/null 2>&1; then
    echo "   • the user manager answers on its bus ✔"
  else
    echo "   ✋ the user manager does not answer on \$XDG_RUNTIME_DIR/bus" >&2
    echo "      ⇒ every systemd-run --user caller (nvim, claude) fails to start" >&2
    echo "      read why: rhx machine.journal.read --scope system --unit $unit --since today" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 1.6.5.usermanager --mode apply" >&2
    failed=1
  fi

  return $failed
}
