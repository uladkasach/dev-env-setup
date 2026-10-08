#!/usr/bin/env bash
# .what = install the revive drop-in for user@.service, and start this seat's
#         user manager if it is down now
# .why  = see `user@.revive.conf`. the drop-in covers every FUTURE death; the
#         start covers the one that may already have happened on this box
#
# guarantee:
#   - idempotent: a byte-equal drop-in, a loaded Restart=always, and a live
#     manager is a [KEEP]
#   - reads state before it asks for root (gotcha.1-6-3-earlyoom..., m2)

grove_provision_1_6_5_usermanager_configure_upsert() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.6.procs/1.6.5.usermanager/user@.revive.conf"
  local live="$GROVE_USERMANAGER_DROPIN"
  local unit="user@$(id -u).service"

  [[ -r "$declared" ]] || { echo "   ✋ the declared drop-in is absent at $declared" >&2; return 1; }

  local file_current=0 loaded=0 alive=0
  cmp -s "$declared" "$live" && file_current=1
  [[ "$(systemctl show -p Restart --value "$unit" 2>/dev/null)" == "always" ]] && loaded=1
  systemctl is-active --quiet "$unit" && alive=1

  if (( file_current && loaded && alive )); then
    echo "   • $unit revives itself, and is alive ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    bundle.root.declines "the user-manager revive" \
      "drop-in current=$file_current, loaded=$loaded, alive=$alive"
    return 0
  fi

  if (( ! file_current )); then
    sudo install -D -m 0644 -o root -g root "$declared" "$live" || {
      echo "   ✋ could not write $live" >&2; return 1; }
    echo "   • revive drop-in written to $live"
  fi

  if (( ! file_current || ! loaded )); then
    sudo systemctl daemon-reload || { echo "   ✋ daemon-reload failed" >&2; return 1; }
    echo "   • systemd reloaded — user@.service now carries Restart=always"
  fi

  if (( ! alive )); then
    sudo systemctl start "$unit" || {
      echo "   ✋ could not start $unit" >&2
      echo "      ⇒ the session bus stays dead, and every systemd-run --user caller fails" >&2
      return 1; }
    echo "   • $unit was down, and is started again"
  fi
}
