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
#   - idempotent: the profile hook is guarded by a grep for its own marker
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
    grove_provision_1_1_keybinds_keynav_autostart
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns every write below
  if ! pkg_can_sudo; then
    bundle.root.declines "the keyd remap confs" \
      "/etc/keyd holds $conf_count conf(s); default.conf $([[ "$default_live" == "$conf_default_want" ]] && echo matches || echo differs); apple.conf $([[ "$apple_live" == "$conf_apple_want" ]] && echo matches || echo differs)"
    grove_provision_1_1_keybinds_keynav_autostart
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
# .what = keynav autostart, at login — user-level, so it needs no root
######################################################################
grove_provision_1_1_keybinds_keynav_autostart() {
  # ⚠️ the guard greps a SLUG MARKER, never the code it writes
  #   - a grep for the command couples the guard to the command's exact text
  #   - any edit to that command stops the guard from ever matching a healthy file
  #   - ⇒ every run appends another copy
  #   - the append is not idempotent, only the guard makes it so
  #   - a `# grove: <slug>` marker is coupled to the CLAIM, so the command is free to change
  #   - (rule.require.idempotent-install-procedures)
  #
  # 🛑 keep the LEGACY grep beside the marker — do not drop it
  #   - every box converged before 2026-07-31 holds the old block, which carries no marker
  #   - the fence word also moved `# devenv:` → `# grove:` on 2026-09-02
  #   - ⇒ on an old box the `$marker` grep MISSES
  #   - `$legacy` matches the CONTENT line, which neither change touched
  #   - so an old box lands on the elif and is left alone
  #   - ⇒ without it, the change that repairs idempotence would break it once on every extant box
  #   - it may be dropped only once no box predates the fence rename
  local profile="$HOME/.profile"
  local marker="# grove: keynav autostart at login"
  local legacy='(keynav && echo "keynav started"'

  if grep -qF "$marker" "$profile" 2>/dev/null; then
    echo "   • keynav autostart already declared"
  elif grep -qF "$legacy" "$profile" 2>/dev/null; then
    echo "   • keynav autostart already declared (pre-marker block; left as is)"
  else
    cat <<'EOF' >> "$profile"

# grove: keynav autostart at login
(keynav && echo "keynav started" || echo "keynav already up") &
EOF
    echo "   • keynav autostart declared in ~/.profile"
  fi
}
