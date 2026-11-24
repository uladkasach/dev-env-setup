#!/usr/bin/env bash
######################################################################
# .what = declare the remap itself — keyd's `default.conf` + `apple.conf`, and keynav's autostart
#
# .why
#   - the key beside the spacebar is super on every board, so the swap is per device
#   - keyd is the one layer that sees which device a key came from
#   - the dir is emptied first, so a stray conf cannot fight by read order
#   - the remap line by line, the two confs, the xkb strip, and keynav: `keyboard.alt-super-per-board`
#
# guarantee:
#   - idempotent: the conf is re-declared from this file's text
#   - idempotent: keynav's autostart entry is compared whole before any write
######################################################################

grove_provision_1_1_keybinds_configure_upsert() {
  ####################################################################
  # 0. the declaration, held in a variable rather than piped straight out
  #
  # .why not a bare heredoc into `sudo tee`
  #   - a write-only heredoc can never be COMPARED
  #   - ⇒ the phase could not answer "would my write change the box" without root
  #   - held here, one declaration serves both the write and the diff
  #   - (`rule.require.judge-declared-state-not-live-state`)
  ####################################################################
  local conf_default_want conf_apple_want
  conf_default_want="$(keybinds_keyd_conf --for builtin)" || return 1
  conf_apple_want="$(keybinds_keyd_conf --for apple)" || return 1

  ####################################################################
  # 1. what is ALREADY true — read before any privilege is asked for
  #
  # 🛑 read the box FIRST, assert root second
  #   - a grove's camper seat holds no sudo by design (`term=seat`)
  #   - 📜 root-first made every camper apply fail over a conf `ground` had already written
  #   - see `bundle.root.declines` for the full measurement
  #
  # ⚠️ .why the CONF COUNT is part of the read
  #   - keyd reads every `.conf` in the dir; a stray `*` match fights by read order
  #   - ⇒ "both confs are correct" alone would let a stray third conf survive a skip
  #   - all three facts must hold, or the write runs (`configure.verify` asserts the same)
  ####################################################################
  local default_live apple_live conf_count
  default_live="$(cat /etc/keyd/default.conf 2>/dev/null || true)"
  apple_live="$(cat /etc/keyd/apple.conf 2>/dev/null || true)"
  conf_count="$(find /etc/keyd -maxdepth 1 -name '*.conf' 2>/dev/null | wc -l)"

  if [[ "$default_live" == "$conf_default_want" && "$apple_live" == "$conf_apple_want" && "$conf_count" -eq 2 ]]; then
    echo "   • keyd remap already declared — default.conf + apple.conf, and no other ✔"
    grove_provision_1_1_keybinds_xkb_swap_strip
    grove_provision_1_1_keybinds_keynav_autostart || return 1
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns every write below
  if ! pkg_can_sudo; then
    bundle.root.declines "the keyd remap confs" \
      "/etc/keyd holds $conf_count conf(s); default.conf $([[ "$default_live" == "$conf_default_want" ]] && echo matches || echo differs); apple.conf $([[ "$apple_live" == "$conf_apple_want" ]] && echo matches || echo differs)"
    grove_provision_1_1_keybinds_keynav_autostart || return 1
    return 0
  fi

  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - with none attached it prompts anyway
  #   - a duct is tmux, so the question sits on the pane and eats the next command sent
  #   - `pkg_install` asserts this already, but a bundle that reaches root DIRECTLY must ask itself
  #   - reached only when this seat CAN sudo, since the gate above returned otherwise
  pkg_assert_sudo || return 1

  sudo mkdir -p /etc/keyd

  # empty the dir first — see .why above
  sudo rm -f /etc/keyd/*.conf 2>/dev/null || true

  printf '%s\n' "$conf_default_want" | sudo tee /etc/keyd/default.conf >/dev/null
  printf '%s\n' "$conf_apple_want" | sudo tee /etc/keyd/apple.conf >/dev/null

  ####################################################################
  # make the conf edit LIVE — a reload on a live daemon, a start only on a dead one
  #
  # 🛑 never `systemctl restart` a live keyd
  #   - at START, keyd waits for every key on every connected board to read released
  #   - a magic keyboard reports BTN_0 (0x100) as held, always
  #   - ⇒ a start with that board connected spins at 100% cpu forever, grabs no
  #     board at all, and caps is plain caps on every keyboard
  #   - boot never hits it: bluetooth connects AFTER keyd is up, via the hotplug
  #     path, which skips the wait
  #   - `keyd reload` re-reads every conf and re-matches every device with no wait
  #   - 📜 measured 2026-10-19: restart → hung, 66 min of cpu; reload → 0%, both boards matched
  ####################################################################
  local keyd_live_cmd="sudo keyd reload"
  systemctl is-active --quiet keyd || keyd_live_cmd="sudo systemctl restart keyd"
  if ! $keyd_live_cmd; then
    echo "   ✋ the confs landed but keyd would not load them ($keyd_live_cmd)" >&2
    echo "      ⇒ so the remap in effect is the PREVIOUS one, and this bundle's" >&2
    echo "        declaration sits on disk with no effect" >&2
    echo "      ⇒ a common cause is a syntax error in a conf above: keyd refuses" >&2
    echo "        to start on a bad config rather than run a partial one" >&2
    echo "      read why: systemctl status keyd    # it quotes the line at fault" >&2
    return 1
  fi
  echo "   • keyd remap declared (default.conf swaps alt/super, apple.conf does not), daemon loaded it ($keyd_live_cmd)"

  grove_provision_1_1_keybinds_xkb_swap_strip
  grove_provision_1_1_keybinds_keynav_autostart
}

######################################################################
# .what = strip cosmic's global xkb alt/super swap, once keyd's per-board swap is live
#
# .why only AFTER keyd's confs are confirmed
#   - strip first and a declined keyd write leaves the builtin unswapped
#   - ⇒ called only from the two paths where keyd's confs hold
#
# .why it must go at all
#   - xkb options apply to every keyboard; keyd's swap already covers the builtin
#   - stacked, the builtin double-swaps back to stock and the apple board swaps
######################################################################
grove_provision_1_1_keybinds_xkb_swap_strip() {
  local xkb="$HOME/.config/cosmic/com.system76.CosmicComp/v1/xkb_config"
  if [[ -f "$xkb" ]] && grep -q 'altwin:swap_lalt_lwin' "$xkb"; then
    sed -i 's/,altwin:swap_lalt_lwin//;s/altwin:swap_lalt_lwin,\?//' "$xkb"
    echo "   • cosmic's global xkb alt/super swap removed — keyd swaps per board now"
    return 0
  fi
  echo "   • no global xkb alt/super swap stacked on keyd's ✔"
}

######################################################################
# .what = keynav starts once per graphical login, from an xdg autostart entry —
#         and never from ~/.profile (the why: `_.sh`, above `keybinds_keynav_entry_at`)
#
# guarantee:
#   - user-level, so it needs no root
#   - idempotent: the strip is a no-op once neither profile line remains, and
#     the entry is rewritten only when its bytes differ from the template
#   - every tier loses the profile lines; only `local@unix` gets the entry,
#     since a cloud grove has no graphical session to read it
######################################################################
grove_provision_1_1_keybinds_keynav_autostart() {
  grove_provision_1_1_keybinds_keynav_profile_strip || return 1

  if [[ "${GROVE_ENV_SERVER:-}" != local@unix ]]; then
    echo "   🌙 keynav autostart declined — tier '${GROVE_ENV_SERVER:-<unset>}' has no graphical session"
    return 0
  fi

  local src at
  src="$(keybinds_keynav_entry_src)"
  at="$(keybinds_keynav_entry_at)"
  if cmp -s "$src" "$at"; then
    echo "   • keynav autostart entry matches this checkout ✔"
    return 0
  fi
  mkdir -p "$(dirname "$at")" || return 1
  cp "$src" "$at" || return 1
  echo "   • keynav autostart entry declared → $at (read at the next graphical login)"
}

######################################################################
# .what = remove both forms of the old keynav start from ~/.profile
#
# .why a line filter, not a block delete
#   - two forms exist: the `# grove:` marker + its command, and the older
#     command alone, with no marker (boxes converged before 2026-07-31)
#   - each line is matched by fixed string, so no regex escape can misfire
#   - every other line of ~/.profile survives byte for byte
#
# .why `cat >` and not `mv`
#   - it writes through the extant inode, so the file's mode and owner hold
######################################################################
grove_provision_1_1_keybinds_keynav_profile_strip() {
  local profile="$HOME/.profile" kept
  if ! keybinds_keynav_profile_holds; then
    echo "   • ~/.profile starts no keynav ✔"
    return 0
  fi
  kept="$(mktemp)" || return 1
  awk -v m="$KEYBINDS_KEYNAV_PROFILE_MARKER" -v l="$KEYBINDS_KEYNAV_PROFILE_LEGACY" \
    'index($0, m) == 0 && index($0, l) == 0' "$profile" > "$kept" \
    && cat "$kept" > "$profile"
  local rc=$?
  rm -f "$kept"
  if [[ "$rc" -ne 0 ]]; then
    echo "   ✋ could not strip the keynav lines from ~/.profile" >&2
    return 1
  fi
  echo "   • keynav start removed from ~/.profile — every login shell had started one"
}
