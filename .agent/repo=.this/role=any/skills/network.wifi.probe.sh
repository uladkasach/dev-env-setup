#!/usr/bin/env bash
######################################################################
# .what = gather the evidence behind "my wifi drops, and a reconnect fixes it"
#
# 🛑 .why this skill exists — a drop that a reconnect repairs names a SYMPTOM
#   shared by several unrelated causes, each with its own repair:
#
#     · the radio's power-save parks it and it never wakes   → powersave off
#     · the driver/firmware wedges (microcode error, reset)  → driver option
#     · the AP deauths or roams us badly (reason codes)      → bssid / band
#     · suspend/resume leaves the link stale                 → resume hook
#     · the link is up and DNS/route went stale              → not wifi at all
#
#   this reads every rung in one pass so the verdict cites evidence, not a guess
#
# usage:
#   rhx network.wifi.probe
#   rhx network.wifi.probe --since '-72h'
#
# guarantee:
#   - READ-ONLY: it changes no config, no link state, no power state
#   - every probe is bounded by a timeout
#   - a reader it cannot run says so; it never reports a clean read it did not earn
######################################################################

set -uo pipefail

SINCE='-48h'

__wifi_help() {
  cat <<'HELP'
📶 network.wifi.probe — gather evidence for wifi that drops until reconnected

  usage:
    rhx network.wifi.probe [--since <journalctl time>]

  options:
    --since   how far back to read the journal   (default: -48h)

  reads: device + driver + chipset · power-save state (radio and NetworkManager)
         · current link and signal · driver/firmware errors · disconnect reason
         codes · suspend/resume events
HELP
}

# .what = run a reader, bounded; print its output, or a named could-not-read line
__wifi_read() {
  local label="$1"; shift
  local out rc=0
  out="$(timeout 10 "$@" 2>&1)" || rc=$?
  if [[ "$rc" -ne 0 && -z "$out" ]]; then
    echo "      ⚠️ could not read ($label): exit $rc"
    return 0
  fi
  printf '%s\n' "$out" | sed 's/^/      /'
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)   SINCE="${2:-}"; shift 2 ;;
      --help|-h) __wifi_help; return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.wifi.probe --help" >&2; return 2 ;;
    esac
  done

  echo "📶 network.wifi.probe --since $SINCE"

  # find the wifi interface
  local iface
  iface="$(timeout 5 nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
  if [[ -z "$iface" ]]; then
    echo "✋ ConstraintError: NetworkManager reports no wifi device" >&2
    return 2
  fi

  # device, driver, chipset
  local sysdev="/sys/class/net/$iface/device"
  echo ""
  echo "── 1. device"
  echo "      iface:    $iface"
  echo "      driver:   $(basename "$(readlink "$sysdev/driver" 2>/dev/null)" 2>/dev/null || echo '?')"
  echo "      pci id:   $(cat "$sysdev/vendor" 2>/dev/null || echo '?'):$(cat "$sysdev/device" 2>/dev/null || echo '?')"
  if command -v lspci >/dev/null; then
    local slot; slot="$(basename "$(readlink -f "$sysdev")")"
    __wifi_read lspci lspci -nnk -s "$slot"
  fi
  echo "      kernel:   $(uname -r)"
  echo "      module params:"
  local d; d="$(basename "$(readlink "$sysdev/driver/module" 2>/dev/null)" 2>/dev/null)"
  if [[ -n "$d" && -d "/sys/module/$d/parameters" ]]; then
    for p in /sys/module/"$d"/parameters/*; do echo "        $(basename "$p")=$(cat "$p" 2>/dev/null || echo '?')"; done
  else
    echo "        (none readable)"
  fi

  # power save — radio, and NetworkManager's declared config
  echo ""
  echo "── 2. power-save"
  if command -v iw >/dev/null; then
    __wifi_read 'iw power_save' iw dev "$iface" get power_save
  else
    echo "      ⚠️ iw is not installed — radio power-save state unread"
    echo "         fix: rhx grove.provision --what 2.1.toolkit --mode apply"
  fi
  echo "      NetworkManager wifi.powersave (2=off 3=on, 0/absent=default→on):"
  local hits
  hits="$(grep -rH 'wifi.powersave' /etc/NetworkManager/conf.d/ /usr/lib/NetworkManager/conf.d/ 2>/dev/null)"
  [[ -n "$hits" ]] && printf '%s\n' "$hits" | sed 's/^/        /' || echo "        (not set in any conf.d — default applies)"

  # current link
  echo ""
  echo "── 3. link"
  __wifi_read 'nmcli wifi' nmcli -f IN-USE,SSID,BSSID,CHAN,FREQ,RATE,SIGNAL,SECURITY device wifi list --rescan no
  if command -v iw >/dev/null; then __wifi_read 'iw link' iw dev "$iface" link; fi

  # the journal: driver/firmware faults, disconnects, suspend
  echo ""
  echo "── 4. kernel + driver events (since $SINCE)"
  __wifi_read 'journal kernel' journalctl -k --since "$SINCE" --no-pager -o short-iso \
    -g "$iface|iwlwifi|ath1|ath9|mt7|rtw|brcm|firmware|microcode|deauth|beacon|PM: suspend exit|PM: hibernation exit" --case-sensitive=false

  echo ""
  echo "── 5. disconnects (since $SINCE)"
  __wifi_read 'journal NM+wpa' journalctl -u NetworkManager -u wpa_supplicant --since "$SINCE" --no-pager -o short-iso \
    -g 'CTRL-EVENT-DISCONNECTED|reason=|state change|deauth|beacon|connectivity|disassoc|supplicant connection state' --case-sensitive=false

  echo ""
  echo "🌲 probe done — read rungs 2, 4, 5 together: the cause is where they agree"
  echo "   a silent link with power-save on, and no deauth or beacon loss?"
  echo "   ⇒ allowlist this driver: howto.allowlist-a-wifi-driver-for-powersave-off"
  return 0
}

main "$@"
