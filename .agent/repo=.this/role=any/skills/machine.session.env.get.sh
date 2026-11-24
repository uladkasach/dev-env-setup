#!/usr/bin/env bash
######################################################################
# .what = show the display + session vars the USER MANAGER holds — the
#         environment every xdg autostart entry and user unit inherits
#
# .why  = an autostart entry runs as a unit of `systemd --user`, never under
#         a shell. so a tool that needs a display (keynav, a tray) starts only
#         if the manager holds DISPLAY / WAYLAND_DISPLAY. a shell's own env
#         says naught about that; this reads the manager's
#
# usage:
#   rhx machine.session.env.get
#
# guarantee:
#   - read-only: `systemctl --user show-environment`, filtered
#   - names each var as held or absent, so an absence is never silent
#   - exit 0 = reported · 1 = the user manager did not answer
######################################################################

set -euo pipefail

env_all="$(systemctl --user show-environment 2>/dev/null)" || {
  echo "💥 MalfunctionError: the user manager did not answer (systemctl --user show-environment)" >&2
  echo "   └─ is it up? rhx grove.provision --what 1.6.5.usermanager --mode plan" >&2
  exit 1
}

echo "🐢 lets read the session tide..."
echo ""
echo "🐚 machine.session.env.get"
echo "   └─ what systemd --user hands to every autostart entry"
vars=(DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DBUS_SESSION_BUS_ADDRESS)
n=${#vars[@]}
for i in "${!vars[@]}"; do
  var="${vars[$i]}"
  glyph="├─"; (( i == n - 1 )) && glyph="└─"
  val="$(printf '%s\n' "$env_all" | awk -F= -v k="$var" '$1 == k { sub(/^[^=]*=/, ""); print; exit }')"
  if [[ -n "$val" ]]; then
    echo "      $glyph ✔ $var=$val"
  else
    echo "      $glyph 🫧 $var absent"
  fi
done
