#!/usr/bin/env bash
######################################################################
# .what = set a display's scale, with an automatic revert unless approved
#
# .why  = a scale change is a felt trial: the human sees it, then decides.
#         a trial that waits on an agent to remember the revert can strand
#         the box in a mode nobody chose — so the revert is armed HERE, in a
#         detached timer, and only `--approve` disarms it
#
# usage:
#   rhx display.scale.set --output DP-8 --scale 2 --revert-after 60
#   rhx display.scale.set --approve               # keep the trial scale
#   rhx display.scale.set --randr-help            # cosmic-randr mode usage
#
# guarantee:
#   - reads the current mode + scale first, and reverts to exactly that
#   - the approve marker is per trial; a stale one never approves a new trial
#   - exit 0 = set · 1 = cosmic-randr failed · 2 = bad input
######################################################################
set -u

marker="$HOME/.cache/display.scale.approve"
output="" scale="" revert_after="" res="" refresh=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --scale) scale="$2"; shift 2 ;;
    --revert-after) revert_after="$2"; shift 2 ;;
    --res) res="$2"; shift 2 ;;          # e.g. 2560x1440; default: keep the current
    --refresh) refresh="$2"; shift 2 ;;  # e.g. 59.951; default: keep the current
    --approve)
      mkdir -p "$(dirname "$marker")" && touch "$marker"
      echo "🐢 shell yeah"
      echo ""
      echo "🖥️  display.scale.set --approve"
      echo "   └─ trial kept; the revert timer will stand down ✔"
      exit 0 ;;
    --randr-help) cosmic-randr mode --help; exit 0 ;;
    --help|-h)
      echo "display.scale.set — set a display scale, auto-revert unless --approve"
      echo "  usage: rhx display.scale.set --output DP-8 --scale 2 --revert-after 60"
      echo "         rhx display.scale.set --approve"
      exit 0 ;;
    *) shift ;;  # rhx passes its own args through
  esac
done

if [[ -z "$output" || -z "$scale" ]]; then
  echo "✋ ConstraintError: --output and --scale are required" >&2
  exit 2
fi

# read the current mode + scale, so the revert restores exactly this
block="$(cosmic-randr list | sed 's/\x1b\[[0-9;]*m//g' | awk -v o="$output" '
  $1 == o { on = 1; next } on && /^[A-Za-z0-9-]+ \(/ { on = 0 } on { print }')"
cur_scale="$(awk -F': ' '/Scale:/ { gsub(/%/, "", $2); print $2 / 100 }' <<<"$block")"
cur_mode="$(awk '/\(current\)/ { print $1, $3; exit }' <<<"$block")"
read -r cur_res cur_hz <<<"$cur_mode"
cur_w="${cur_res%x*}" cur_h="${cur_res#*x}"

if [[ -z "$cur_scale" || -z "$cur_w" || -z "$cur_hz" ]]; then
  echo "💥 MalfunctionError: could not read the current mode of $output from cosmic-randr list" >&2
  exit 1
fi

echo "🐢 heres the wave..."
echo ""
echo "🖥️  display.scale.set --output $output --scale $scale"
echo "   ├─ was: ${cur_w}x${cur_h} @ ${cur_hz} Hz, scale $cur_scale"

new_w="$cur_w" new_h="$cur_h" new_hz="${refresh:-$cur_hz}"
[[ -n "$res" ]] && { new_w="${res%x*}"; new_h="${res#*x}"; }

rm -f "$marker"
if ! cosmic-randr mode --scale "$scale" --refresh "$new_hz" "$output" "$new_w" "$new_h"; then
  echo "   └─ 💥 cosmic-randr refused the mode" >&2
  exit 1
fi
echo "   ├─ now: ${new_w}x${new_h} @ ${new_hz} Hz, scale $scale"

if [[ -n "$revert_after" ]]; then
  # detached: the revert fires whether or not anyone remembers it
  nohup bash -c "
    sleep $revert_after
    [[ -f '$marker' ]] && exit 0
    cosmic-randr mode --scale '$cur_scale' --refresh '$cur_hz' '$output' '$cur_w' '$cur_h'
  " >/dev/null 2>&1 &
  echo "   └─ reverts to ${cur_w}x${cur_h} at scale $cur_scale in ${revert_after}s unless: rhx display.scale.set --approve"
else
  echo "   └─ no revert armed"
fi
exit 0
