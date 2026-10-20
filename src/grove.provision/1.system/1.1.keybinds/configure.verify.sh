#!/usr/bin/env bash
######################################################################
# .what = prove the remap is DECLARED as this bundle declares it
#
# .why the confs are compared WHOLE against the renderer
#   - `[[ -f default.conf ]]` passes on every broken keyd config ever written
#   - `_.sh`'s `keybinds_keyd_conf` is the one source both phases read
#   - ⇒ a byte compare catches every drift: capslock, the tap timeout, the
#     vimarrows layer, the apple ids, and the per-board alt/super swap
#   - 📜 an absent `overload_tap_timeout` surfaces months later as a stray escape
#     on a slow ctrl+click — and it reads as an nvim bug
#
# .why the dir is asserted to hold exactly TWO confs
#   - keyd reads every `.conf` in `/etc/keyd/`
#   - `default.conf` (every board but apple) and `apple.conf` (apple only) partition
#     the devices, so they never fight
#   - a THIRD file that also matches `*` would fight `default.conf` by read order
#   - that is not a syntax error, so keyd reports no complaint
#
# .why cosmic's xkb swap is asserted ABSENT
#   - `altwin:swap_lalt_lwin` applies to every keyboard, and stacks on keyd's swap
#   - stacked, the builtin double-swaps back to stock and the apple board swaps
#
# .why the effective remap is UNVERIFIED here
#   - to observe capslock now sends ctrl you must read a key event
#   - that needs an interactive tty AND a human hand
#   - an upgrade run has neither: its stdin is closed and its stdout is a pipe
#   - ⇒ the last claim is stated with a 🌙, never encoded in an exit code
#   - (rule.forbid.failhide)
#
# guarantee:
#   - READ-ONLY. it reads /etc/keyd, the xkb config, and systemd; repairs no state
#
# exit:
#   0 = the declaration holds, as far as it can be observed from here
#   1 = a conf is absent or drifted, a third conf is present, or the xkb swap stacks
######################################################################

grove_provision_1_1_keybinds_configure_verify() {
  local failed=0
  local fix="sudo -v && rhx grove.provision --what 1.1.keybinds --mode apply"

  ####################################################################
  # 1. each conf matches its rendered declaration
  ####################################################################
  local board file want live
  for board in builtin apple; do
    file="/etc/keyd/default.conf"
    [[ "$board" == "apple" ]] && file="/etc/keyd/apple.conf"
    want="$(keybinds_keyd_conf --for "$board")" || return 1
    live="$(cat "$file" 2>/dev/null || true)"

    if [[ -z "$live" ]]; then
      echo "   ✋ no keyd conf at $file" >&2
      echo "      ⇒ the $board boards get no remap: capslock is capslock, and" >&2
      echo "        the alt/super position is whatever the board ships with" >&2
      echo "      fix: $fix" >&2
      failed=$(( failed + 1 ))
    elif [[ "$live" == "$want" ]]; then
      echo "   • $file matches its declaration ($board boards) ✔"
    else
      echo "   ✋ $file has DRIFTED from its declaration ($board boards)" >&2
      diff <(printf '%s\n' "$want") <(printf '%s\n' "$live") | sed 's/^/        /' >&2
      echo "      fix: $fix" >&2
      failed=$(( failed + 1 ))
    fi
  done

  ####################################################################
  # 2. exactly two confs — a third `*` match would fight default.conf
  ####################################################################
  local count; count="$(find /etc/keyd -maxdepth 1 -name '*.conf' 2>/dev/null | wc -l)"
  if [[ "$count" -eq 2 ]]; then
    echo "   • exactly two keyd confs (default + apple) ✔"
  else
    echo "   ✋ /etc/keyd holds $count .conf files, not 2" >&2
    echo "      ⇒ keyd reads them ALL; a stray one that matches '*' fights" >&2
    echo "        default.conf, and read order picks the winner with no complaint" >&2
    find /etc/keyd -maxdepth 1 -name '*.conf' 2>/dev/null | sed 's/^/        /' >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 3. no global xkb swap stacked on keyd's per-board one
  ####################################################################
  local xkb="$HOME/.config/cosmic/com.system76.CosmicComp/v1/xkb_config"
  if [[ -f "$xkb" ]] && grep -q 'altwin:swap_lalt_lwin' "$xkb"; then
    echo "   ✋ cosmic's xkb options still carry altwin:swap_lalt_lwin" >&2
    echo "      ⇒ it applies to every board and stacks on keyd's swap: the builtin" >&2
    echo "        swaps back to stock, and the apple board swaps the wrong way" >&2
    echo "      fix: $fix" >&2
    failed=$(( failed + 1 ))
  else
    echo "   • no global xkb alt/super swap ✔"
  fi

  ####################################################################
  # 4. the daemon read it — a restart is what makes a conf edit live
  ####################################################################
  if systemctl is-active --quiet keyd; then
    echo "   • keyd daemon is active, so the confs above are the live ones ✔"
  else
    echo "   ✋ the keyd daemon is not active, so NO conf is in effect" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 4b. active is not enough — a keyd stuck at start grabs NO board
  #
  # .why
  #   - at start keyd waits for every key on every board to read released
  #   - a magic keyboard reports BTN_0 as held, always, so that wait never ends
  #   - ⇒ the unit is `active`, cpu sits at 100%, and caps is plain caps everywhere
  #   - an idle keyd uses ~0 cpu, so >50% over one second is the stuck loop
  #   - /proc/<pid>/stat is world-readable, so this needs no root
  ####################################################################
  local keyd_pid ticks_before ticks_after hz
  keyd_pid="$(systemctl show -p MainPID --value keyd 2>/dev/null)"
  if [[ -n "$keyd_pid" && "$keyd_pid" != "0" && -r "/proc/$keyd_pid/stat" ]]; then
    hz="$(getconf CLK_TCK)"
    ticks_before="$(awk '{print $14 + $15}' "/proc/$keyd_pid/stat")"
    sleep 1
    ticks_after="$(awk '{print $14 + $15}' "/proc/$keyd_pid/stat" 2>/dev/null || echo "$ticks_before")"
    if (( (ticks_after - ticks_before) * 2 > hz )); then
      echo "   ✋ keyd is stuck — it burns a full cpu and has grabbed no keyboard" >&2
      echo "      ⇒ it was started while a board reports a key held (a magic keyboard's" >&2
      echo "        BTN_0), and keyd's start waits for all keys released, forever" >&2
      echo "      fix: turn the magic keyboard off, then: sudo systemctl restart keyd" >&2
      echo "           then turn the board back on (a hotplug skips the wait)" >&2
      failed=$(( failed + 1 ))
    else
      echo "   • keyd is idle, not stuck in its start-up key wait ✔"
    fi
  fi

  ####################################################################
  # 5. whether the kernel honors it — not observable from here
  ####################################################################
  echo "   🌙 unverified — whether a press now DELIVERS the remap needs a key event,"
  echo "      so it needs an interactive tty and a human hand. this run has neither"
  echo "      to check by hand, on EACH board: hold capslock + c in a shell (interrupts),"
  echo "      and the key beside the spacebar + a letter should act as super"
  echo "      to see which board a key came from: sudo keyd monitor"

  [[ "$failed" -eq 0 ]] || return 1
}
