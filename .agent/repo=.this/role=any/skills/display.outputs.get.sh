#!/usr/bin/env bash
######################################################################
# .what = list every display output: its mode, refresh, scale, and how it connects
#
# .why  = a desktop that turns sluggish the moment a monitor is plugged in
#         is a DISPLAY question first — mode, refresh, and the link — and
#         neither ps nor top can see it
#
# usage:
#   rhx display.outputs.get
#
# guarantee:
#   - read-only: cosmic-randr list (wayland, no root) and /sys/class/drm
#   - exits 0 always (a report is not a verdict)
######################################################################
set -u

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
  echo "display.outputs.get — list display outputs, their modes, and their links"
  echo "  usage: rhx display.outputs.get"
  exit 0
}

echo "🐢 lets see what's lit up"
echo ""
echo "🖥️  display.outputs.get"
echo "   ├─ connectors (kernel)"
for c in /sys/class/drm/card*-*; do
  [[ -r "$c/status" ]] || continue
  [[ "$(cat "$c/status")" == "connected" ]] || continue
  modes="$(head -n 3 "$c/modes" 2>/dev/null | tr '\n' ' ')"
  echo "   │  └─ $(basename "$c")  modes: ${modes:-?}"
done
echo "   └─ cosmic-randr list"
if command -v cosmic-randr >/dev/null; then
  cosmic-randr list | sed 's/^/      /'
else
  echo "      🌙 cosmic-randr absent"
fi
exit 0
