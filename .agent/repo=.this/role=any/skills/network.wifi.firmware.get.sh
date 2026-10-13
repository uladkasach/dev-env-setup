#!/usr/bin/env bash
######################################################################
# .what = read which firmware the wifi radio runs, which package ships it,
#         and the files on disk it was loaded from
#
# .why  = "is the firmware old?" has three separate answers that are easy to
#         fold: the build the RADIO reports, the PACKAGE version installed, and
#         the FILES that package placed. a new package can ship an unchanged
#         blob, so only all three together say whether an upgrade could help
#
# usage:
#   rhx network.wifi.firmware.get
#
# guarantee:
#   - READ-ONLY: it changes no package, file, or link state
#   - every read is bounded by a timeout
######################################################################

set -uo pipefail

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) echo "📶 network.wifi.firmware.get — the wifi radio's firmware: build, package, files"; return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.wifi.firmware.get --help" >&2; return 2 ;;
    esac
  done

  local iface driver
  iface="$(timeout 5 nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
  if [[ -z "$iface" ]]; then
    echo "✋ ConstraintError: NetworkManager reports no wifi device" >&2
    return 2
  fi
  driver="$(basename "$(readlink "/sys/class/net/$iface/device/driver" 2>/dev/null)" 2>/dev/null)"

  echo "📶 network.wifi.firmware.get"
  echo "   iface: $iface · driver: ${driver:-?} · kernel: $(uname -r)"

  # 1. what the radio reports it booted — the build actually in use
  echo ""
  echo "── 1. loaded (this boot)"
  local loaded
  loaded="$(timeout 10 journalctl -k -b 0 --no-pager -o cat 2>/dev/null | grep -E "^${driver}.*(fw_version|fw_build|firmware|board)" | head -n 6)"
  [[ -n "$loaded" ]] && printf '%s\n' "$loaded" | sed 's/^/      /' || echo "      · no firmware line in this boot's kernel log"

  # 2. the package that ships the blobs, and when it was installed
  echo ""
  echo "── 2. package"
  local pkg
  for pkg in linux-firmware linux-firmware-ath; do
    local v
    v="$(timeout 5 dpkg-query -W -f '${Version}\t${Status}' "$pkg" 2>/dev/null)"
    [[ -n "$v" ]] && echo "      $pkg: $v"
  done
  echo "      install history (apt):"
  local hist
  hist="$(timeout 5 zgrep -h -E '^(Start-Date|Commandline|Upgrade|Install).*linux-firmware' /var/log/apt/history.log* 2>/dev/null | tail -n 6)"
  [[ -n "$hist" ]] && printf '%s\n' "$hist" | cut -c1-200 | sed 's/^/        /' || echo "        · no linux-firmware entry in the apt history kept on disk"
  echo "      os installed (root fs created): $(timeout 5 stat -c %w / 2>/dev/null || echo '?')"

  # 3. the files the driver loads from, with the date each landed
  echo ""
  echo "── 3. files"
  local dir
  case "$driver" in
    ath11k_pci) dir=/lib/firmware/ath11k ;;
    ath10k_pci) dir=/lib/firmware/ath10k ;;
    iwlwifi)    dir=/lib/firmware ;;
    *)          dir="" ;;
  esac
  if [[ -n "$dir" && -d "$dir" ]]; then
    timeout 5 find "$dir" -maxdepth 3 \( -name 'amss*' -o -name 'm3*' -o -name 'board*' -o -name 'iwlwifi-*' \) \
      -printf '      %TY-%Tm-%Td  %10s  %p\n' 2>/dev/null | sort -k3 | head -n 30
  else
    echo "      · no firmware dir known for driver '${driver:-?}'"
  fi

  echo ""
  echo "🌲 done — the build in rung 1 is what the radio runs; rung 2 says whether apt could change it"
}

main "$@"
