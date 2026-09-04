#!/usr/bin/env bash
######################################################################
# .what = declare the remap itself — keyd's `default.conf`, and keynav's autostart
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
# .why every prior *.conf is removed first
#   - keyd reads EVERY `.conf` in `/etc/keyd/`
#   - two files that both match `[ids] *` fight, and read order picks the winner
#   - a rename of this file in a past revision would leave its old copy live
#   - ⇒ the dir is emptied and re-declared (rule.require.judge-declared-state-not-live-state)
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
  local conf_want
  conf_want="$(cat <<'EOF'
[ids]
*

[global]
# if capslock held > 200ms, skip the escape tap (helps with ctrl+click)
overload_tap_timeout = 200

[main]
# capslock = control (held) / escape (tapped)
capslock = overload(control, esc)

# disable disruptive keys
coffee  = noop
sleep   = noop
suspend = noop
power   = noop

# vim-style arrows with right alt, right ctrl, or right meta (magic keyboard)
rightalt = layer(vimarrows)
rightcontrol = layer(vimarrows)
rightmeta = layer(vimarrows)

[vimarrows]
h = left
j = down
k = up
l = right
EOF
)"

  ####################################################################
  # 1. what is ALREADY true — read before any privilege is asked for
  #
  # 🛑 read the box FIRST, assert root second
  #   - a grove's camper seat holds no sudo by design (`term=seat`)
  #   - 📜 root-first made every camper apply fail over a conf `ground` had already written
  #   - see `bundle.root.declines` for the full measurement
  #
  # ⚠️ .why the CONF COUNT is part of the read
  #   - keyd reads every `.conf` in the dir, and two `[ids] *` files fight by read order
  #   - ⇒ "default.conf is correct" alone would let a stray second conf survive a skip
  #   - both facts must hold, or the write runs (`configure.verify` asserts the same pair)
  ####################################################################
  local conf_live conf_count
  conf_live="$(cat /etc/keyd/default.conf 2>/dev/null || true)"
  conf_count="$(find /etc/keyd -maxdepth 1 -name '*.conf' 2>/dev/null | wc -l)"

  if [[ "$conf_live" == "$conf_want" && "$conf_count" -eq 1 ]]; then
    echo "   • keyd remap already declared, and it is the only conf ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns every write below
  if ! pkg_can_sudo; then
    bundle.root.declines "the keyd remap conf" \
      "/etc/keyd holds $conf_count conf(s); default.conf $([[ "$conf_live" == "$conf_want" ]] && echo matches || echo differs)"
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

  printf '%s\n' "$conf_want" | sudo tee /etc/keyd/default.conf >/dev/null

  ####################################################################
  # a restart is what makes a conf edit LIVE — keyd reads its config at start only
  ####################################################################
  if ! sudo systemctl restart keyd; then
    echo "   ✋ the conf landed but keyd would not restart to read it" >&2
    echo "      ⇒ so the remap in effect is the PREVIOUS one, and this bundle's" >&2
    echo "        declaration sits on disk with no effect" >&2
    echo "      ⇒ a common cause is a syntax error in the conf above: keyd refuses" >&2
    echo "        to start on a bad config rather than run a partial one" >&2
    echo "      read why: systemctl status keyd    # it quotes the line at fault" >&2
    return 1
  fi
  echo "   • keyd remap declared, daemon restarted"

  ####################################################################
  # keynav autostart, at login
  ####################################################################
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
