#!/usr/bin/env bash
######################################################################
# .what = prove the remap is DECLARED as this bundle declares it
#
# .why the conf's PRESENCE is not the claim
#   - `[[ -f default.conf ]]` passes on every broken keyd config ever written
#   - so this asserts the two lines that carry the value: capslock, and the vimarrows layer
#   - plus `overload_tap_timeout`, which only matters when it is absent
#   - 📜 its absence surfaces months later as a stray escape on a slow ctrl+click
#   - ⇒ and it reads as an nvim bug
#
# .why the dir is asserted to hold exactly ONE conf
#   - keyd reads every `.conf` in `/etc/keyd/`, and two `[ids] *` files fight by read order
#   - a second file is not a syntax error, so keyd reports no complaint
#   - the remap simply becomes whichever file won
#   - ⇒ that is invisible from a read of this repo, so it is asserted here
#
# .why the effective remap is UNVERIFIED here
#   - to observe capslock now sends ctrl you must read a key event
#   - that needs an interactive tty AND a human hand
#   - an upgrade run has neither: its stdin is closed and its stdout is a pipe
#   - ⇒ the last claim is stated with a 🌙, never encoded in an exit code
#   - (rule.forbid.failhide)
#
# guarantee:
#   - READ-ONLY. it reads /etc/keyd and queries systemd; repairs no state
#
# exit:
#   0 = the declaration holds, as far as it can be observed from here
#   1 = a declared line is ABSENT, or a second conf is present to fight it
######################################################################

grove_provision_1_1_keybinds_configure_verify() {
  local conf="/etc/keyd/default.conf"
  local failed=0

  ####################################################################
  # 1. the conf exists
  ####################################################################
  if [[ ! -f "$conf" ]]; then
    echo "   ✋ no keyd config at $conf" >&2
    echo "      ⇒ configure.upsert did not take, so capslock is still capslock" >&2
    echo "      fix: rhx grove.provision --what 1.1.keybinds --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 2. exactly one conf — a second would fight this one by read order
  ####################################################################
  local count; count="$(find /etc/keyd -maxdepth 1 -name '*.conf' 2>/dev/null | wc -l)"
  if [[ "$count" -eq 1 ]]; then
    echo "   • exactly one keyd conf ✔"
  else
    echo "   ✋ /etc/keyd holds $count .conf files, not 1" >&2
    echo "      ⇒ keyd reads them ALL, and two that each match '[ids] *' fight;" >&2
    echo "        the winner depends on read order, and keyd reports no complaint" >&2
    find /etc/keyd -maxdepth 1 -name '*.conf' 2>/dev/null | sed 's/^/        /' >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 3. capslock — the load-bear line
  ####################################################################
  if grep -Eq '^[[:space:]]*capslock[[:space:]]*=[[:space:]]*overload\(control,[[:space:]]*esc\)' "$conf"; then
    echo "   • capslock = overload(control, esc) declared ✔"
  else
    echo "   ✋ capslock is NOT declared as overload(control, esc)" >&2
    echo "      ⇒ every tmux, nvim, and kitty keybind this repo declares assumes" >&2
    echo "        ctrl is under the left pinky. without this they are contortions" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 4. the tap timeout — the line whose absence hides for months
  ####################################################################
  if grep -Eq '^[[:space:]]*overload_tap_timeout[[:space:]]*=' "$conf"; then
    echo "   • overload_tap_timeout declared ✔"
  else
    echo "   ✋ overload_tap_timeout is NOT declared" >&2
    echo "      ⇒ a slow ctrl+click emits a stray escape on release, which nvim" >&2
    echo "        reads as a mode change mid-gesture — and it reads as an nvim bug" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 5. the vim arrow layer
  ####################################################################
  if grep -q '^\[vimarrows\]' "$conf"; then
    echo "   • the vimarrows layer is declared ✔"
  else
    echo "   ✋ the [vimarrows] layer is ABSENT from the conf" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 6. the daemon read it — a restart is what makes a conf edit live
  ####################################################################
  if systemctl is-active --quiet keyd; then
    echo "   • keyd daemon is active, so the conf above is the live one ✔"
  else
    echo "   ✋ the keyd daemon is not active, so NO conf is in effect" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 7. whether the kernel honors it — not observable from here
  ####################################################################
  echo "   🌙 unverified — whether a capslock press now DELIVERS ctrl needs a key"
  echo "      event, so it needs an interactive tty and a human hand. this run has"
  echo "      neither. the declaration and the live daemon above did hold"
  echo "      to check by hand: hold capslock and press c in a shell — it should"
  echo "      interrupt, not type C"

  [[ "$failed" -eq 0 ]] || return 1
}
