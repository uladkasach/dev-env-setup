#!/usr/bin/env bash
######################################################################
# .what = prove wifi power-save is off for the listed drivers: declared,
#         effective, and live
#
# .why three claims, each with its own defect
#   - declared   the file on disk matches what the driver list renders
#   - effective  NetworkManager's MERGED config carries our scoped section —
#                only the merge shows whether it parsed and survived
#   - live       each listed radio reads off. `none` (no listed card) is the
#                expected answer on another laptop; `unread` is a 🌙, since
#                `iw` arrives with `2.1.toolkit`, after this bundle
#
# guarantee:
#   - READ-ONLY. it repairs no state
#
# exit:
#   0 = declared and effective, and each listed radio is off, absent, or unread
#   1 = a claim does not hold, and which is named
######################################################################

grove_provision_1_11_wifi_configure_verify() {
  local dst="$GROVE_PROVISION_1_11_WIFI_CONF_AT"

  if [[ ! -d /etc/NetworkManager/conf.d ]] || ! command -v nmcli >/dev/null 2>&1; then
    echo "   🌙 no NetworkManager on this box — no wifi power-save to verify"
    return 0
  fi

  local failed=0

  # 1. declared
  local declared=0
  if [[ "$(cat "$dst" 2>/dev/null)" == "$(grove_provision_1_11_wifi_conf_render)" ]]; then
    declared=1
    echo "   • declared: $dst ✔"
  else
    echo "   ✋ $dst is absent or differs from what the driver list renders" >&2
    echo "      fix: rhx grove.provision --what 1.11.wifi --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  # 2. effective — our scoped section, as NetworkManager merges it
  local merged
  merged="$(timeout 10 NetworkManager --print-config 2>/dev/null \
    | awk '/^\[/{ sect = $0 } sect == "[connection-wifi-powersave-off]" && /^wifi.powersave=/{ v = $0 } END { print v }')"
  if [[ "$declared" -eq 0 ]]; then
    : # the cause is claim 1, already named
  elif [[ "$merged" == "wifi.powersave=2" ]]; then
    echo "   • effective: [connection-wifi-powersave-off] $merged ✔"
  elif [[ -z "$merged" ]] && ! timeout 10 NetworkManager --print-config >/dev/null 2>&1; then
    echo "   🌙 could not read NetworkManager's merged config — effective value unread"
  else
    echo "   ✋ NetworkManager's merged config does not carry our scoped section" >&2
    echo "      ⇒ the file is on disk, so NetworkManager rejected or overrode it" >&2
    echo "      read why: NetworkManager --print-config | grep -A3 wifi-powersave-off" >&2
    failed=$(( failed + 1 ))
  fi

  # 3. live
  local radio
  radio="$(grove_provision_1_11_wifi_radio_state)"
  case "$radio" in
    off)  echo "   • listed radio(s): power-save off ✔" ;;
    none) echo "   • no listed card here (${GROVE_PROVISION_1_11_WIFI_DRIVERS[*]}) — the distro default stands ✔" ;;
    on)
      echo "   ✋ a listed radio still runs power-save" >&2
      echo "      fix: rhx grove.provision --what 1.11.wifi --mode apply" >&2
      failed=$(( failed + 1 ))
      ;;
    *) echo "   🌙 listed radio state unread (no iw)" ;;
  esac

  [[ "$failed" -eq 0 ]] || return 1
}
