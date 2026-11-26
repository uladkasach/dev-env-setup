#!/usr/bin/env bash
######################################################################
# .what = show every display output cosmic knows: its mode, scale,
#         position, and whether it is enabled
#
# .why  = "the monitor looks zoomed" is almost always one of two facts —
#         a scale above 100%, or a mode below the panel's native one.
#         both live in cosmic's output state, and this reads them in one
#         call rather than an ad-hoc `cosmic-randr` each time
#
# usage:
#   rhx display.output.get
#
# guarantee:
#   - read-only: never changes a mode or a scale
#   - bounded: every read carries a timeout
#   - exit 0 = answered, 1 = cosmic-randr could not answer, 2 = absent tool
######################################################################

set -uo pipefail

case "${1:-}" in
  --help|-h)
    echo "display.output.get — show each output's mode, scale, and position (read-only)"
    echo "  usage: rhx display.output.get"
    exit 0 ;;
esac

if ! command -v cosmic-randr >/dev/null 2>&1; then
  echo "✋ ConstraintError: cosmic-randr is not on PATH" >&2
  echo "   ⇒ this skill reads cosmic's output state; it needs a cosmic session" >&2
  exit 2
fi

echo "🖥️  display.output.get"
echo ""

out="$(timeout 10 cosmic-randr list 2>&1)"; rc=$?
if [[ $rc -ne 0 ]]; then
  echo "💥 MalfunctionError: cosmic-randr list returned $rc" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
printf '%s\n' "$out"

state="$HOME/.local/state/cosmic-comp/outputs.ron"
if [[ -r "$state" ]]; then
  echo ""
  echo "── saved output config: $state"
  timeout 5 cat "$state"
fi
exit 0
