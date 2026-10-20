#!/usr/bin/env bash
######################################################################
# .what = turn caps lock OFF, when no physical key can
#
# .why  = `1.1.keybinds` maps capslock to ctrl/esc, so a latched caps lock
#         has no key left to clear it. it latches when keyd is down or
#         stuck (a raw capslock press reaches the box) and keyd then comes back
#         - ⇒ this sends ONE capslock press through keyd's virtual keyboard
#
# usage:
#   rhx input.keyboard.capslock.off
#
# guarantee:
#   - idempotent: reads the caps lock LEDs first; presses only when one is lit
#   - reads /sys (no root); the press goes over keyd's socket (`keyd do`)
#   - exit 0 = caps lock off · 1 = the press failed · 2 = keyd absent
######################################################################
set -uo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "input.keyboard.capslock.off — clear a latched caps lock via keyd"
  echo "  usage: rhx input.keyboard.capslock.off"
  exit 0
fi

# is any board's caps lock led lit?
__capslock_is_on() {
  local led
  for led in /sys/class/leds/*::capslock/brightness; do
    [[ -r "$led" && "$(cat "$led")" != "0" ]] && return 0
  done
  return 1
}

echo "🐢 lets un-shout"
echo ""
echo "⌨️  input.keyboard.capslock.off"

# show every led read — zero leds read must never pass as "off"
leds_read=0
for led in /sys/class/leds/*::capslock/brightness; do
  [[ -r "$led" ]] || continue
  leds_read=$((leds_read + 1))
  echo "   ├─ $(basename "$(dirname "$led")") = $(cat "$led")"
done
if [[ "$leds_read" -eq 0 ]]; then
  echo "   └─ ✋ no caps lock led is readable under /sys/class/leds, so the state is unknown" >&2
  exit 2
fi

# --force: the leds can read off while the desktop still holds caps on (a desync
# after keyd restarts), and only a press clears that — so press regardless
force=0
for arg in "$@"; do [[ "$arg" == "--force" ]] && force=1; done

if [[ "$force" -eq 0 ]] && ! __capslock_is_on; then
  echo "   └─ caps lock already off ✔ (desktop still shouts? rerun with --force)"
  exit 0
fi

if ! command -v keyd >/dev/null; then
  echo "   └─ ✋ keyd is not on PATH, so no virtual key can be pressed" >&2
  exit 2
fi

# keyd's socket is root's, so the press needs a cached sudo — never a prompt
if ! sudo -n true 2>/dev/null; then
  echo "   └─ ✋ the press goes over keyd's root socket, and sudo is not cached" >&2
  echo "      fix: sudo -v && rhx input.keyboard.capslock.off$([[ "$force" -eq 1 ]] && echo ' --force')" >&2
  exit 2
fi

if ! sudo -n keyd do capslock; then
  echo "   └─ 💥 keyd refused the press — is the daemon up? systemctl status keyd" >&2
  exit 1
fi
sleep 0.3

if [[ "$force" -eq 0 ]] && __capslock_is_on; then
  echo "   └─ 💥 pressed capslock, but a caps lock led is still lit" >&2
  exit 1
fi
echo "   └─ caps lock off ✔"
