#!/usr/bin/env bash
######################################################################
# .what = list every keyboard on this box with its keyd id, and which keyd conf claims it
#
# .why this skill exists
#   - `1.1.keybinds` swaps alt/super PER BOARD: the builtin swaps, apple boards do not
#   - that split keys on a `vendor:product` id, and a new board needs its id added
#   - the id is not printed anywhere a human looks: `/proc/bus/input/devices`
#     spreads it across a multi-line record, keyd ignores some devices, and
#     its own virtual keyboard shows up beside the real ones
#   - `sudo keyd monitor` also names ids, but it needs root and a key press
#   - ⇒ this reads the record with no root, filters to real keyboards, and
#     answers the one question that matters: does this board get the swap?
#
# usage:
#   rhx input.keyboard.ids
#
# guarantee:
#   - READ-ONLY. it reads /proc and this repo's `1.1.keybinds/_.sh`; changes naught
#   - the conf verdict reads the SAME id list the bundle renders from
#   - exit 0 = listed · exit 2 = no keyboard found
######################################################################

set -uo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'HELP'
⌨️  input.keyboard.ids — list keyboards, their keyd ids, and which keyd conf claims each

  usage:
    rhx input.keyboard.ids

  output, per keyboard:
    vendor:product   the id keyd's [ids] section matches on
    conf             apple.conf (no alt/super swap) or default.conf (swaps alt/super)

  to add an apple-layout board:
    1. run this with the board connected, note its vendor:product
    2. add it to KEYBINDS_APPLE_IDS in src/grove.provision/1.system/1.1.keybinds/_.sh
    3. sudo -v && rhx grove.provision --what 1.1.keybinds --mode apply
HELP
  exit 0
fi

# the apple id list — read from the bundle, never copied (one declaration)
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
bundle_sh="$repo_root/src/grove.provision/1.system/1.1.keybinds/_.sh"
KEYBINDS_APPLE_IDS=()
if [[ -f "$bundle_sh" ]]; then
  # shellcheck disable=SC1090
  source "$bundle_sh"
fi

echo "🐢 lets see who's on the line"
echo ""
echo "⌨️  input.keyboard.ids"

# walk /proc/bus/input/devices, one blank-line-separated record per device
rows=()
vendor="" product="" name="" handlers="" bus=""
__emit() {
  # keep only devices with a kbd handler AND a full keymap (a real keyboard),
  # and drop keyd's own virtual devices (vendor 0fac)
  [[ "$handlers" == *kbd* && "$handlers" == *leds* ]] || return 0
  [[ "$vendor" == "0fac" ]] && return 0
  local id="$vendor:$product" conf="default.conf — swaps alt/super" a
  for a in "${KEYBINDS_APPLE_IDS[@]}"; do
    [[ "$a" == "$id" ]] && conf="apple.conf — no swap"
  done
  rows+=("$id|$name|$bus|$conf")
}
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    I:*)
      bus="$(sed -n 's/.*Bus=\([0-9a-f]*\).*/\1/p' <<<"$line")"
      vendor="$(sed -n 's/.*Vendor=\([0-9a-f]*\).*/\1/p' <<<"$line")"
      product="$(sed -n 's/.*Product=\([0-9a-f]*\).*/\1/p' <<<"$line")"
      ;;
    N:*) name="$(sed -n 's/^N: Name="\(.*\)"$/\1/p' <<<"$line")" ;;
    H:*) handlers="$line" ;;
    "")  __emit; vendor="" product="" name="" handlers="" bus="" ;;
  esac
done < /proc/bus/input/devices
__emit

# an unread id list would mark every board default.conf — say so, never pass it silently
if [[ "${#KEYBINDS_APPLE_IDS[@]}" -eq 0 ]]; then
  echo "   ├─ 🟡 could not read the apple id list from $bundle_sh — verdicts below assume none"
fi

if [[ "${#rows[@]}" -eq 0 ]]; then
  echo "   └─ ✋ no keyboard found in /proc/bus/input/devices"
  exit 2
fi

echo "   └─ keyboards"
i=0
for r in "${rows[@]}"; do
  i=$((i + 1))
  IFS='|' read -r id name bus conf <<<"$r"
  branch="├─"; cont="│ "
  [[ "$i" -eq "${#rows[@]}" ]] && branch="└─" && cont="  "
  busname="bus $bus"
  case "$bus" in 0003) busname="usb" ;; 0005) busname="bluetooth" ;; 0011) busname="builtin (i8042)" ;; esac
  echo "      $branch $id  $name  ($busname)"
  echo "      $cont  └─ $conf"
done
exit 0
