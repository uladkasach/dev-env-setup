#!/usr/bin/env bash
######################################################################
# .what = set one display output's scale (and, optionally, its mode)
#
# .why  = a monitor that "looks zoomed" at its native mode has a scale
#         too high for its size — cosmic picks or remembers a scale per
#         output set, and a new monitor can inherit the laptop panel's
#         2.0. this sets it in one bounded call, and verifies it took
#
# usage:
#   rhx display.output.set --output DP-7 --scale 1.5                  # plan
#   rhx display.output.set --output DP-7 --scale 1.5 --mode apply
#   rhx display.output.set --output DP-7 --scale 1.5 --size 3840x2160 --mode apply
#
# guarantee:
#   - plan mode is the default; the change takes a deliberate --mode apply
#   - the mode defaults to the output's CURRENT mode, so a scale change
#     never moves the resolution by accident
#   - it re-reads the output after apply and fails loud on a mismatch
#   - cosmic persists the result itself (outputs.ron), per output set
#   - exit 0 = set, 1 = cosmic-randr malfunction, 2 = bad input
######################################################################

set -uo pipefail

OUTPUT=""
SCALE=""
SIZE=""
MODE=plan

__help() {
  echo "display.output.set — set an output's scale (and mode), then verify"
  echo "  usage: rhx display.output.set --output <name> --scale <1|1.25|1.5|1.75|2> [--size WxH] [--mode plan|apply]"
  echo "  read the names first: rhx display.output.get"
}

# .what = strip color codes from cosmic-randr's output
__plain() { sed -E 's/\x1b\[[0-9;]*m//g'; }

# .what = print one output's block of `cosmic-randr list`
__block() {
  timeout 10 cosmic-randr list 2>/dev/null | __plain |
    awk -v o="$1" '/^[^ ]/ { on = ($1 == o) } on'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --scale)  SCALE="${2:-}"; shift 2 ;;
    --size)   SIZE="${2:-}"; shift 2 ;;
    --mode)   MODE="${2:-}"; shift 2 ;;
    --help|-h) __help; exit 0 ;;
    --repo|--role|--skill) shift 2 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; __help >&2; exit 2 ;;
  esac
done

[[ "$MODE" == plan || "$MODE" == apply ]] || { echo "✋ ConstraintError: --mode wants plan|apply" >&2; exit 2; }
[[ -n "$OUTPUT" && -n "$SCALE" ]] || { echo "✋ ConstraintError: --output and --scale are required" >&2; __help >&2; exit 2; }
[[ "$SCALE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "✋ ConstraintError: --scale wants a number like 1.5, got '$SCALE'" >&2; exit 2; }
command -v cosmic-randr >/dev/null 2>&1 || { echo "✋ ConstraintError: cosmic-randr is not on PATH" >&2; exit 2; }

block="$(__block "$OUTPUT")"
if [[ -z "$block" ]]; then
  echo "✋ ConstraintError: no output named '$OUTPUT'" >&2
  echo "   read the names: rhx display.output.get" >&2
  exit 2
fi

# the current mode is the default, so a scale change never moves the resolution
cur="$(printf '%s\n' "$block" | awk '/\(current\)/ { print $1, $3; exit }')"
cur_size="${cur%% *}"; cur_hz="${cur##* }"
scale_now="$(printf '%s\n' "$block" | awk -F': ' '/Scale:/ { print $2; exit }')"
SIZE="${SIZE:-$cur_size}"
[[ "$SIZE" =~ ^([0-9]+)x([0-9]+)$ ]] || { echo "✋ ConstraintError: --size wants WxH, got '$SIZE'" >&2; exit 2; }
w="${BASH_REMATCH[1]}"; h="${BASH_REMATCH[2]}"

# the refresh rides along only when the size is unchanged
args=(mode --scale "$SCALE")
[[ "$SIZE" == "$cur_size" && -n "$cur_hz" ]] && args+=(--refresh "$cur_hz")
args+=("$OUTPUT" "$w" "$h")

echo "🖥️  display.output.set --mode $MODE"
echo "   ├─ output: $OUTPUT"
echo "   ├─ now:    $cur_size @ ${cur_hz:-?} Hz, scale $scale_now"
echo "   └─ want:   $SIZE, scale $(awk -v s="$SCALE" 'BEGIN { printf "%d%%", s * 100 }')"

if [[ "$MODE" == plan ]]; then
  echo ""
  echo "   🌙 plan — apply would run: cosmic-randr ${args[*]}"
  echo "   run it: rhx display.output.set --output $OUTPUT --scale $SCALE${SIZE:+ --size $SIZE} --mode apply"
  exit 0
fi

if ! err="$(timeout 15 cosmic-randr "${args[@]}" 2>&1)"; then
  echo "💥 MalfunctionError: cosmic-randr ${args[*]} failed" >&2
  printf '%s\n' "$err" >&2
  exit 1
fi

# verify — re-read the output, never trust the exit code alone
after="$(__block "$OUTPUT")"
scale_after="$(printf '%s\n' "$after" | awk -F': ' '/Scale:/ { print $2; exit }')"
size_after="$(printf '%s\n' "$after" | awk '/\(current\)/ { print $1; exit }')"
want_pct="$(awk -v s="$SCALE" 'BEGIN { printf "%d%%", s * 100 }')"
if [[ "$scale_after" != "$want_pct" || "$size_after" != "$SIZE" ]]; then
  echo "✋ the output did not take it: $size_after, scale $scale_after (wanted $SIZE, $want_pct)" >&2
  exit 1
fi
echo ""
echo "✔ $OUTPUT is now $size_after at $scale_after"
exit 0
