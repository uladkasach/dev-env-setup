#!/usr/bin/env bash
######################################################################
# .what = place the driver-scoped power-save-off file, have NetworkManager
#         reread it, and turn power-save off on each allowlisted radio now
#
# .why the file lands on EVERY box with NetworkManager
#   - it is scoped by `match-device`, so on a laptop with another card it
#     matches no device and changes none — a harmless declaration
#   - ⇒ a card swap onto a listed driver is covered with no second apply
#
# .why the live write as well as the file
#   - NetworkManager applies `wifi.powersave` when a connection ACTIVATES, so
#     the file alone waits for the next reconnect
#   - `iw … set power_save off` takes effect now, with no drop of the link
#
# .why the skip-guard reads BOTH the file and the radio
#   - a guard on the file alone would skip a box whose radio still runs
#     power-save, and its verify would then name a re-apply that skips again
#
# guarantee:
#   - idempotent: the file is written only when it differs; `iw … off` on an
#     off radio is a no-op
#   - reads before it asks for root (`bundle.root.declines`)
######################################################################

grove_provision_1_11_wifi_configure_upsert() {
  local dst="$GROVE_PROVISION_1_11_WIFI_CONF_AT"

  # 0. decline where no NetworkManager reads conf.d — no reader, no effect
  if [[ ! -d /etc/NetworkManager/conf.d ]] || ! command -v nmcli >/dev/null 2>&1; then
    echo "   🌙 no NetworkManager on this box — wifi power-save has no reader here"
    return 0
  fi

  # 1. what already holds — read before any privilege is asked for
  local want radio file_ok=0
  want="$(grove_provision_1_11_wifi_conf_render)"
  radio="$(grove_provision_1_11_wifi_radio_state)"
  [[ "$(cat "$dst" 2>/dev/null)" == "$want" ]] && file_ok=1

  if [[ "$file_ok" -eq 1 && "$radio" != on ]]; then
    echo "   • power-save off declared for ${GROVE_PROVISION_1_11_WIFI_DRIVERS[*]} · radio: $radio ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it
  if ! pkg_can_sudo; then
    bundle.root.declines "wifi power-save" "file declared: $([[ $file_ok -eq 1 ]] && echo yes || echo no) · radio: $radio"
    return 0
  fi
  pkg_assert_sudo || return 1

  # 2. the declaration — so every future activation of a listed card comes up off
  if [[ "$file_ok" -eq 0 ]]; then
    printf '%s\n' "$want" | sudo tee "$dst" >/dev/null || {
      echo "   ✋ could not write $dst" >&2
      return 1
    }
    sudo chmod 0644 "$dst"
    echo "   • declared: $dst (drivers: ${GROVE_PROVISION_1_11_WIFI_DRIVERS[*]})"
  fi

  if ! sudo nmcli general reload conf; then
    echo "   ✋ NetworkManager refused to reload its config" >&2
    echo "      ⇒ the file is on disk, so it takes at the next NetworkManager start" >&2
    echo "      read why: journalctl -u NetworkManager -n 30" >&2
    return 1
  fi
  echo "   • NetworkManager reread its config"

  # 3. the live radios — now, without a reconnect
  local ifaces iface
  ifaces="$(grove_provision_1_11_wifi_ifaces_listed)"
  if [[ -z "$ifaces" ]]; then
    echo "   • no listed card on this box — its radios keep the distro default"
    return 0
  fi
  if ! command -v iw >/dev/null 2>&1; then
    echo "   🌙 iw is absent, so the radio keeps its current state until the next reconnect"
    echo "      ⇒ \`2.1.toolkit\` installs iw later in this same run"
    return 0
  fi

  while IFS= read -r iface; do
    if ! sudo iw dev "$iface" set power_save off; then
      echo "   ✋ iw could not turn power-save off on $iface" >&2
      echo "      ⇒ the file is declared, so it takes on the next reconnect" >&2
      return 1
    fi
    echo "   • $iface: power-save off, live"
  done <<< "$ifaces"
}
