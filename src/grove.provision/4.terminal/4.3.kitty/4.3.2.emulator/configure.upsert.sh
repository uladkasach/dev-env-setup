#!/usr/bin/env bash
######################################################################
# .what
#   - shape kitty as declared: its conf, its kittens, its theme, its icon
#   - and its role as the system default terminal
#
# .why
#   - one phase, five writes: a split verdict would report 4 passes on 1 failed write
#   - the default-terminal write comes LAST: it resolves `command -v kitty`, which
#     this bundle's own provision phase must have already placed
#   - the conf is COPIED from a tracked peer file, never a heredoc: kitty takes
#     the LAST assignment of a key, so a copy makes the on-disk conf a pure
#     function of the checked-in source (rule.require.judge-declared-state-not-live-state)
#   - idempotent: each write copies or re-registers, safe to repeat
######################################################################

grove_provision_4_3_2_emulator_configure_upsert() {
  ####################################################################
  # 1. kitty.conf, its kittens, and its theme — copied from tracked sources
  #
  # refs: https://sw.kovidgoyal.net/kitty/conf/
  #       https://sw.kovidgoyal.net/kitty/remote-control/
  ####################################################################
  local bundle_dir="$GROVE_SRC/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator"
  mkdir -p "$HOME/.config/kitty/themes"

  cp "$bundle_dir/kitty.conf" "$HOME/.config/kitty/kitty.conf"
  echo "   • kitty.conf declared (~/.config/kitty/kitty.conf)"

  cp "$bundle_dir/copy_notify.py" "$HOME/.config/kitty/copy_notify.py"
  cp "$bundle_dir/reboot_window.py" "$HOME/.config/kitty/reboot_window.py"
  echo "   • kittens declared (copy_notify.py, reboot_window.py)"

  cp "$bundle_dir/desert.conf" "$HOME/.config/kitty/themes/desert.conf"
  echo "   • desert theme declared (~/.config/kitty/themes/desert.conf)"

  ####################################################################
  # 2. the custom icon, across both surfaces that render one
  #
  #   1. dock/launcher/taskbar — the .desktop Icon= plus the wayland app_id match
  #   2. window titlebar — kitty's own ~/.config/kitty/kitty.app.png
  #
  # .why
  #   - the two surfaces are independent: one alone leaves the other stock
  #   - the asset path derives from `$GROVE_SRC`, the run's own checkout, so a
  #     worktree never resolves a hardcoded ~/git/more/dev-env-setup/assets/
  #   - ref: https://sw.kovidgoyal.net/kitty/faq/
  ####################################################################
  local icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
  local desktop_file="$HOME/.local/share/applications/kitty.desktop"
  local icon_src="$GROVE_SRC/../assets/kitty-icon.png"

  if [[ ! -f "$icon_src" ]]; then
    ####################################################################
    # .an absent asset is a 🌙, not a ✋: kitty, its conf, its theme, and its
    #   alternative are all unaffected
    #
    # .why the reason names the TRANSPORT
    #   - this leaf has NO `GROVE_ENV_SERVER` gate, so it RUNS on a grove
    #   - `git.grove.push --from src` sends `src/`, and `assets/` sits BESIDE it
    #   - .refs = gotcha.grove-push-into-names-the-destination
    ####################################################################
    echo "   🌙 no custom icon asset here, so kitty keeps its stock one"
    echo "      ⇒ looked in: $icon_src"
    if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
      echo "      on $GROVE_ENV_SERVER this is EXPECTED: a box is seeded by"
      echo "      'git.grove.push --from src', and assets/ sits beside src/ —"
      echo "      so the transport never carried it. the checkout is intact"
    fi
    echo "      the conf, theme, and default-terminal claims are unaffected"
  else
    # install into the hicolor theme under BOTH names
    #   - kitty.png is the theme name a wayland compositor resolves from app_id
    #   - kitty reports app_id=kitty, so without it the dock falls back to stock
    #   - kitty-custom.png is the absolute path the .desktop Icon= points at
    mkdir -p "$icon_dir"
    cp "$icon_src" "$icon_dir/kitty.png"
    cp "$icon_src" "$icon_dir/kitty-custom.png"

    # kitty's native window-titlebar icon, read from its config dir at startup
    cp "$icon_src" "$HOME/.config/kitty/kitty.app.png"

    mkdir -p "$(dirname "$desktop_file")"
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Kitty
GenericName=Terminal emulator
Comment=Fast, feature-rich, GPU based terminal
TryExec=kitty
# stderr goes to /dev/null: kitty logs [PARSE ERROR] noise (e.g. xterm
# modifyOtherKeys) shared across every os-window in the instance, so the
# mute stops the leak into whichever terminal launched the root kitty
Exec=sh -c 'exec kitty 2>/dev/null'
Icon=$icon_dir/kitty-custom.png
# StartupWMClass binds the live wayland window (app_id=kitty) to this entry,
# so the dock honors Icon=
StartupWMClass=kitty
Categories=System;TerminalEmulator;
EOF

    # flush the icon cache, so the dock re-reads it
    #   - `|| true`: a headless box has no gtk cache to flush and no dock to read it
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

    echo "   • custom icon declared (dock + titlebar; logout to flush the cache)"
  fi

  ####################################################################
  # 3. LAST: kitty as the system default terminal (ctrl+alt+t)
  #
  # .why
  #   - this bundle's provision phase symlinks the tarball to /usr/local/bin/kitty
  #     BEFORE this phase runs, so an absent binary here means that phase
  #     reported a pass it had not earned
  #   - a ✋ here, never a skip (rule.forbid.failhide)
  ####################################################################
  local kitty_bin
  if ! kitty_bin="$(command -v kitty)"; then
    echo "   ✋ kitty is not on PATH, so it cannot be made the default terminal" >&2
    echo "      ⇒ this bundle's provision phase symlinks /usr/local/bin/kitty" >&2
    echo "        BEFORE this phase runs, so an absent binary here means that" >&2
    echo "        phase reported a pass it did not earn" >&2
    echo "      read why: ls -l /usr/local/bin/kitty ; ls -l /opt/kitty.app/bin/kitty" >&2
    return 1
  fi

  ####################################################################
  # .the SEAT gate — a seat with no root READS the box-wide fact, never sets it
  #
  # .why
  #   - `x-terminal-emulator` is a BOX-WIDE alternative under /usr/bin
  #   - `ground` holds NOPASSWD sudo; the camper, which does the work, holds none
  #   - the grant is ground's (rule.require.seam-claims-have-an-owner)
  #   - .refs = define.provision-defect-shapes, shape 2 (grove-ahbode-v20260811)
  ####################################################################
  local live_alt
  live_alt="$(update-alternatives --query x-terminal-emulator 2>/dev/null \
    | grep -E '^Value: ' | awk '{print $2}')"

  if [[ "$live_alt" == "$kitty_bin" ]]; then
    echo "   • default terminal: kitty ($kitty_bin) — already selected box-wide ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    bundle.root.declines "the default terminal" \
      "x-terminal-emulator → ${live_alt:-（unset）}"
    return 0
  fi

  # `sudo` prompts even with no terminal attached, and a duct is tmux — so the
  # question sits on the pane and eats the next command. `pkg_assert_sudo` is
  # the belt to `pkg_can_sudo`'s brace, since a credential can lapse between
  pkg_assert_sudo || return 1

  ####################################################################
  # register at 60, then force-select
  #   - a distro package can register its own terminal at any time; an
  #     auto-mode box then picks the highest priority
  #   - 60 keeps kitty above the debian defaults, where xterm registers at 20
  ####################################################################
  if ! sudo update-alternatives --install /usr/bin/x-terminal-emulator \
    x-terminal-emulator "$kitty_bin" 60; then
    echo "   ✋ could not register kitty as an x-terminal-emulator alternative" >&2
    echo "      ⇒ ctrl+alt+t and every 'x-terminal-emulator' caller keep whichever" >&2
    echo "        terminal holds the alternative now" >&2
    return 1
  fi

  if ! sudo update-alternatives --set x-terminal-emulator "$kitty_bin"; then
    echo "   ✋ kitty is registered but was not SELECTED as the default" >&2
    echo "      ⇒ registration alone only makes it available; the highest" >&2
    echo "        priority wins only in auto mode, and a prior --set pinned" >&2
    echo "        manual mode to another terminal" >&2
    echo "      read why: update-alternatives --display x-terminal-emulator" >&2
    return 1
  fi

  echo "   • default terminal: kitty ($kitty_bin)"
}
