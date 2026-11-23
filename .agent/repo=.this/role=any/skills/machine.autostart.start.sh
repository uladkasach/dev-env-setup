#!/usr/bin/env bash
######################################################################
# .what = start one xdg autostart entry NOW, the way login starts it
#
# .why  = at login, systemd's xdg-autostart generator turns each
#         `~/.config/autostart/<name>.desktop` into a user unit,
#         `app-<name>@autostart.service`, and starts it with the user
#         manager's environment. to change an entry and wait for the next
#         login to learn whether it works is a slow, blind loop. this runs
#         the SAME unit, so an entry is proven in seconds
#
#         what it cannot prove: that the desktop raises autostart at login,
#         nor when the display appears at that moment. those show at a login
#
# usage:
#   rhx machine.autostart.start --entry keynav
#
# guarantee:
#   - reruns the generators (`systemctl --user daemon-reload`), so an entry
#     written since login is picked up
#   - restart, not start: idempotent, and a stale run is replaced
#   - reports the unit's state and its main process after a 2s settle
#   - exit 0 = active · 1 = the unit failed or was never generated · 2 = bad input
######################################################################

set -euo pipefail

ENTRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --entry) ENTRY="${2:-}"; shift 2 ;;
    --repo|--role|--skill) shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ENTRY" ]]; then
  echo "✋ ConstraintError: --entry <name> is required (the <name> of ~/.config/autostart/<name>.desktop)" >&2
  exit 2
fi

entry_at="$HOME/.config/autostart/${ENTRY}.desktop"
unit="app-${ENTRY}@autostart.service"

echo "🐢 lets paddle it out..."
echo ""
echo "🐚 machine.autostart.start --entry $ENTRY"

if [[ ! -f "$entry_at" ]]; then
  echo "   └─ ✋ no entry at $entry_at" >&2
  echo "✋ ConstraintError: no autostart entry named '$ENTRY'" >&2
  echo "   └─ the entries this box holds: ls ~/.config/autostart/" >&2
  exit 2
fi
echo "   ├─ entry: $entry_at"

# rerun the generators so an entry written since login becomes a unit
systemctl --user daemon-reload
if ! systemctl --user cat "$unit" >/dev/null 2>&1; then
  echo "   └─ ✋ the generator made no unit $unit" >&2
  echo "💥 MalfunctionError: systemd produced no unit for this entry" >&2
  echo "   └─ read why: rhx machine.journal.read --scope user --grep xdg-autostart" >&2
  exit 1
fi
echo "   ├─ unit: $unit (generated ✔)"

systemctl --user restart "$unit" || true
sleep 2

state="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
pid="$(systemctl --user show -p MainPID --value "$unit" 2>/dev/null || echo 0)"
if [[ "$state" == active && -n "$pid" && "$pid" != 0 ]]; then
  comm="$(cat "/proc/$pid/comm" 2>/dev/null || echo '?')"
  ppid="$(awk '{ sub(/^.*\) /, ""); print $2 }' "/proc/$pid/stat" 2>/dev/null || echo '?')"
  pcomm="$(cat "/proc/$ppid/comm" 2>/dev/null || echo '?')"
  echo "   └─ ✨ active"
  echo "      ├─ main: pid $pid ($comm)"
  echo "      └─ parent: pid $ppid ($pcomm) — the user manager, not a shell"
  exit 0
fi

echo "   └─ ✋ state: ${state:-unknown}" >&2
echo "💥 MalfunctionError: $unit did not stay up" >&2
echo "   └─ read why: rhx machine.journal.read --scope user --unit $unit --since -5m" >&2
exit 1
