#!/usr/bin/env bash
######################################################################
# .what = declare the remap itself — keyd's `default.conf` + `apple.conf`, and keynav's autostart
#
# .where the conf text lives
#   - `_.sh` renders both confs (`keybinds_keyd_conf`), so upsert and verify share one source
#   - the lines below explain what that rendered text does
#
# .the remap, line by line
#   - `capslock = overload(control, esc)` — held is ctrl, tapped is escape
#   - capslock is the largest key nearest the pinky and its stock function is used by nobody
#   - `overload_tap_timeout = 200` drops the tap-escape after 200ms of hold
#   - without it a slow ctrl+click emits a stray escape that nvim reads as a mode change
#   - `coffee / sleep / suspend / power = noop` — these sit near the arrow cluster
#   - a misfire there suspends the box mid-work
#   - `1.2.power` blocks the same acts at the systemd layer, this blocks them at the DEVICE layer
#   - ⇒ only the device layer catches a key that never reaches logind
#   - `rightalt / rightcontrol / rightmeta = layer(vimarrows)` — three keys, one layer
#   - rightalt on a laptop, rightcontrol on the hhkb, rightmeta on an apple magic keyboard
#   - all three are declared because one human moves between all three boards
#
# .why TWO confs — the alt/super swap is per keyboard
#   - the key beside the spacebar should be super on every board
#   - a pc board (the builtin) puts alt there, so `default.conf` swaps leftalt ⇄ leftmeta
#   - an apple board already puts cmd (meta) there, so `apple.conf` must NOT swap
#   - 📜 the swap once lived in cosmic's xkb options, which apply to EVERY keyboard
#     at once — so it was right for the builtin and backwards for the apple board
#   - ⇒ the swap moved to keyd, the one layer that sees which device a key came from
#   - the shared remap is declared once below and composed into both files,
#     since keyd applies exactly ONE conf per device
#
# .why the two confs cannot fight
#   - `default.conf` matches `*` and EXCLUDES the apple ids (`-vendor:product`)
#   - `apple.conf` names exactly those ids
#   - ⇒ each device matches one file, and read order decides naught
#
# .why every prior *.conf is removed first
#   - keyd reads EVERY `.conf` in `/etc/keyd/`
#   - a stray file that also matches `*` would fight `default.conf` by read order
#   - a rename of this file in a past revision would leave its old copy live
#   - ⇒ the dir is emptied and re-declared (rule.require.judge-declared-state-not-live-state)
#
# .why the xkb swap is stripped here
#   - `altwin:swap_lalt_lwin` in cosmic's xkb options stacks on keyd's swap
#   - stacked, the builtin double-swaps back to stock and the apple board swaps
#   - ⇒ keyd owns the swap, so this phase removes the xkb one (user-level, no root)
#
# .why the keynav hook is in `~/.profile`, not a systemd user unit
#   - keynav needs a live X/wayland session to attach to
#   - `~/.profile` is read at login, when that session exists
#   - a boot-time unit would start before it and exit
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
  # a restart is what makes a conf edit LIVE — keyd reads its config at start only
  ####################################################################
  if ! sudo systemctl restart keyd; then
    echo "   ✋ the confs landed but keyd would not restart to read them" >&2
    echo "      ⇒ so the remap in effect is the PREVIOUS one, and this bundle's" >&2
    echo "        declaration sits on disk with no effect" >&2
    echo "      ⇒ a common cause is a syntax error in a conf above: keyd refuses" >&2
    echo "        to start on a bad config rather than run a partial one" >&2
    echo "      read why: systemctl status keyd    # it quotes the line at fault" >&2
    return 1
  fi
  echo "   • keyd remap declared (default.conf swaps alt/super, apple.conf does not), daemon restarted"

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
