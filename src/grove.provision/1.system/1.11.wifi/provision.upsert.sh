#!/usr/bin/env bash
######################################################################
# .what = install the wifi stall watchdog — a root-owned copy of the
#         executable and its system unit — and enable it
#
# .why the skip-guard reads CONTENT and unit state, never presence
#   - a presence test makes the install write-once, so a fix to the watchdog
#     would reach no box that already holds it (`1.8.tmpfiles` paid for this)
#   - `grove_provision_1_11_wifi_watchdog_state` is the reader the verify asks
#
# ⚠️ .why `daemon-reload` and a RESTART, not `enable --now` alone
#   - systemd caches unit files, so a rewrite with no reload leaves the old
#     definition live
#   - `enable --now` starts a stopped unit and leaves a live one alone, so a
#     new executable would wait for the next boot. a restart puts it live now
#
# guarantee:
#   - idempotent: a converged box is skipped; a drifted one is re-copied
#   - reads before it asks for root (`bundle.root.declines`)
######################################################################

grove_provision_1_11_wifi_provision_upsert() {
  local unit="$GROVE_PROVISION_1_11_WIFI_WATCHDOG_UNIT"

  # 0. decline where it would watch naught — no NetworkManager to reconnect, or no radio
  if ! command -v nmcli >/dev/null 2>&1; then
    echo "   🌙 no NetworkManager on this box — the watchdog has no link to reconnect"
    return 0
  fi
  if [[ "$(grove_provision_1_11_wifi_has_radio)" == no ]]; then
    echo "   🌙 no wifi radio on this box — the watchdog has no link to watch"
    return 0
  fi

  # 1. what already holds — read before any privilege is asked for
  local state
  state="$(grove_provision_1_11_wifi_watchdog_state)"
  if [[ "$state" == converged ]]; then
    echo "   • the watchdog matches this checkout, and $unit is enabled and active ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it
  if ! pkg_can_sudo; then
    bundle.root.declines "the wifi stall watchdog" \
      "$unit is $(systemctl is-active "$unit" 2>/dev/null || echo inactive); files: $state"
    return 0
  fi
  pkg_assert_sudo || return 1

  # 2. the two files — each from a declared source, root-owned
  local pair name rest dst mode src
  for pair in "${GROVE_PROVISION_1_11_WIFI_WATCHDOG_PAIRS[@]}"; do
    name="${pair%%:*}"; rest="${pair#*:}"; dst="${rest%:*}"; mode="${rest##*:}"
    src="$GROVE_SRC/machine/$name"
    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $name at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete" >&2
      return 1
    fi
    sudo install -D -m "$mode" -o root -g root "$src" "$dst" || {
      echo "   ✋ could not install $dst" >&2
      return 1
    }
  done
  echo "   • the watchdog and $unit declared"

  # 3. reload FIRST — see the header for why a rewrite alone does no work
  sudo systemctl daemon-reload || {
    echo "   ✋ systemctl daemon-reload failed" >&2
    echo "      ⇒ the new unit is on disk and the OLD definition stays live" >&2
    return 1
  }
  if ! sudo systemctl enable "$unit" || ! sudo systemctl restart "$unit"; then
    echo "   ✋ could not enable and start $unit" >&2
    echo "      ⇒ a silent stall goes unrecorded, and waits for a human reconnect" >&2
    echo "      read why: journalctl -u $unit -n 30" >&2
    return 1
  fi
  echo "   • $unit enabled and (re)started"
}
