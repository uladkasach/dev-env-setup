#!/usr/bin/env bash
######################################################################
# .what = two answers to one defect — a wifi link that goes silent while
#         it stays associated:
#           · configure: power-save OFF for the drivers that wedge under it,
#             and ON (the distro default) for every other card
#           · provision: a stall watchdog that records the link, driver, and
#             firmware state at the stall, then reconnects
#
# .why
#   - a QCA6390 (`ath11k_pci`) goes silent under power-save until a human reconnects
#   - power-save stays on for any card whose driver wakes it correctly
#   - the watchdog records the state a stall erases, then reconnects
#   - the measurements and the design: `howto.allowlist-a-wifi-driver-for-powersave-off`
#
# usage:
#   rhx grove.provision --what 1.11.wifi --mode apply
######################################################################

# .what = the drivers whose cards stall under wifi power-save — declared ONCE
# .why the conf file, the live write, and the verify all derive from this list
GROVE_PROVISION_1_11_WIFI_DRIVERS=(
  ath11k_pci   # qualcomm QCA6390 — measured 2026-10-03..05, see header
)

# .what = where the declaration lands, declared ONCE for both halves
GROVE_PROVISION_1_11_WIFI_CONF_AT="/etc/NetworkManager/conf.d/wifi-powersave-off.conf"

# .what = the conf file's content, rendered from the driver list
# .why rendered, not a static asset — a static file would be a second
#   declaration of the driver list, free to drift from the array above
grove_provision_1_11_wifi_conf_render() {
  local spec="" driver
  for driver in "${GROVE_PROVISION_1_11_WIFI_DRIVERS[@]}"; do
    spec="${spec:+$spec,}driver:$driver"
  done
  cat <<CONF
# owned by dev-env-setup \`1.11.wifi\` — edits here are lost on the next apply
#
# wifi power-save OFF (2) for the drivers below, which wedge under it.
# every other card keeps the distro default.
[connection-wifi-powersave-off]
match-device=$spec
wifi.powersave=2
CONF
}

# .what = the wifi interfaces whose driver is on the allowlist, one per line
grove_provision_1_11_wifi_ifaces_listed() {
  local dir iface driver want
  for dir in /sys/class/net/*/wireless; do
    [[ -d "$dir" ]] || continue
    iface="$(basename "$(dirname "$dir")")"
    driver="$(basename "$(readlink "/sys/class/net/$iface/device/driver" 2>/dev/null)" 2>/dev/null)"
    for want in "${GROVE_PROVISION_1_11_WIFI_DRIVERS[@]}"; do
      [[ "$driver" == "$want" ]] && echo "$iface"
    done
  done
}

# .what = the LIVE power-save state of the allowlisted radios
#   `..._radio_state` → off | on | none | unread
# .why
#   - ONE reader, asked by BOTH halves, so the upsert's skip-guard and the
#     verify cannot cut the set two ways
#   - `none` = no allowlisted card on this box — the common case on another
#     laptop, and no work is owed
#   - `unread` = an allowlisted card is here and `iw` could not answer. to
#     fold it into `off` passes a rung never measured
grove_provision_1_11_wifi_radio_state() {
  local ifaces iface out
  ifaces="$(grove_provision_1_11_wifi_ifaces_listed)"
  [[ -n "$ifaces" ]] || { echo none; return 0; }
  command -v iw >/dev/null 2>&1 || { echo unread; return 0; }

  while IFS= read -r iface; do
    out="$(timeout 5 iw dev "$iface" get power_save 2>/dev/null)" || { echo unread; return 0; }
    [[ "$out" == *": on"* ]] && { echo on; return 0; }
    [[ "$out" == *": off"* ]] || { echo unread; return 0; }
  done <<< "$ifaces"

  echo off
}

# .what = the stall watchdog's two installed artifacts, declared ONCE
# .why the executable is a root-owned COPY, never a path into a checkout —
#   a root unit that ran code from a user-writable home would hand root to
#   whoever can write there
GROVE_PROVISION_1_11_WIFI_WATCHDOG_UNIT="wifi-link-watchdog.service"
GROVE_PROVISION_1_11_WIFI_WATCHDOG_PAIRS=(
  "machine_wifi_link_watchdog:/usr/local/libexec/dev-env-setup/machine_wifi_link_watchdog:0755"
  "wifi-link-watchdog.service:/etc/systemd/system/wifi-link-watchdog.service:0644"
)

# .what = does this box have a wifi radio for the watchdog to watch? yes | no
grove_provision_1_11_wifi_has_radio() {
  local dir
  for dir in /sys/class/net/*/wireless; do
    [[ -d "$dir" ]] && { echo yes; return 0; }
  done
  echo no
}

# .what = the watchdog's installed state
#   `..._watchdog_state` → converged | drifted
# .why ONE reader, asked by BOTH halves: the upsert's skip-guard and the
#   verify read the same bytes and the same unit state
grove_provision_1_11_wifi_watchdog_state() {
  local pair name dst
  for pair in "${GROVE_PROVISION_1_11_WIFI_WATCHDOG_PAIRS[@]}"; do
    name="${pair%%:*}"; dst="${pair#*:}"; dst="${dst%:*}"
    cmp -s "$GROVE_SRC/machine/$name" "$dst" || { echo drifted; return 0; }
  done
  [[ "$(systemctl is-enabled "$GROVE_PROVISION_1_11_WIFI_WATCHDOG_UNIT" 2>/dev/null)" == enabled ]] || { echo drifted; return 0; }
  [[ "$(systemctl is-active "$GROVE_PROVISION_1_11_WIFI_WATCHDOG_UNIT" 2>/dev/null)" == active ]] || { echo drifted; return 0; }
  echo converged
}

grove_provision_1_11_wifi() {
  bundle.upgrade 1.11.wifi.provision.upsert
  bundle.upgrade 1.11.wifi.provision.verify
  bundle.upgrade 1.11.wifi.configure.upsert
  bundle.upgrade 1.11.wifi.configure.verify
}
