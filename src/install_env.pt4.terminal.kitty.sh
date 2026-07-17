#!/usr/bin/env bash
######################################################################
# .what = install and configure kitty terminal
# .why  = remote control via socket IPC (kitten @), gpu-accelerated
#
# usage:
#   source ~/git/more/dev-env-setup/src/install_env.pt4.terminal.kitty.sh
#   install_kitty
#   configure_kitty
#   configure_kitty_theme
#   configure_kitty_icon
#
# verify:
#   kitty -o allow_remote_control=yes &
#   kitten @ --to "unix:@kitty-$!" ls
#   (from inside kitty, just: kitten @ ls)
#
# note: apt install required (flatpak blocks socket IPC for remote control)
######################################################################

install_kitty() {
  #########################
  ## kitty: from the official binary tarball (version-pinned)
  ## ref: https://github.com/kovidgoyal/kitty/releases
  ##
  ## why tarball, not apt:
  ##  - ubuntu noble ships kitty ~0.32, which predates the fix for issue #7136
  ##    (kitty sent spurious key-release events for Enter/Tab/Backspace under the
  ##    keyboard protocol; nvim counted each release as a second press → doubles)
  ##  - the fix landed in kitty ~0.35; the official tarball tracks latest (0.47+)
  ##  - not flatpak, so remote-control sockets (kitten @) still work
  #########################
  local version="0.47.4"
  local archive="kitty-${version}-x86_64.txz"
  local base="https://github.com/kovidgoyal/kitty/releases/download/v${version}"
  local url="${base}/${archive}"
  local sig_url="${base}/${archive}.sig"
  local tmp_dir="/tmp/kitty-install"

  # kitty signs every release artifact with kovid goyal's gpg key.
  # pin the fingerprint so a swapped key cannot slip a forged tarball past us.
  # ref: https://github.com/kovidgoyal/kitty/discussions/5942
  local key_url="https://github.com/kovidgoyal.gpg"
  local key_fpr="3CE1780F78DD88DF45194FD706BC317B515ACE7C"

  # also pin the sha256 (belt-and-suspenders atop gpg). the hash came from
  # github's api asset digest for v0.47.4. to bump: update version + sha256
  # together, from `gh api .../releases/tags/vX | .assets[].digest`.
  local sha256="bc230142b2bd27f2a4bf1b1b67575f3d397a4ea2cc83f4ac2b912c306a939693"

  # drop the apt-managed kitty binary so /usr/bin/kitty can't shadow the tarball.
  # keep kitty-terminfo: it ships only the xterm-kitty terminfo entry (no binary),
  # which tmux/ssh need — it is (re)installed at the end of this function.
  sudo apt remove kitty -y || true

  # fetch tarball + detached signature
  rm -rf "$tmp_dir" && mkdir -p "$tmp_dir"
  curl -fsSL "$url" -o "$tmp_dir/$archive"
  curl -fsSL "$sig_url" -o "$tmp_dir/${archive}.sig"

  # fail fast unless the download matches the pinned sha256
  if ! echo "${sha256}  $tmp_dir/$archive" | sha256sum -c - >/dev/null 2>&1; then
    echo "⛈️  kitty install aborted: sha256 mismatch (expected $sha256)"
    rm -rf "$tmp_dir"
    return 1
  fi

  # verify the signature in an isolated gpg home (leaves the user gpg store untouched)
  local gnupg_dir="$tmp_dir/gnupg"
  mkdir -p "$gnupg_dir" && chmod 700 "$gnupg_dir"
  curl -fsSL "$key_url" -o "$tmp_dir/kovid.gpg"
  gpg --homedir "$gnupg_dir" --import "$tmp_dir/kovid.gpg"

  # fail fast unless the imported key matches the pinned fingerprint
  if ! gpg --homedir "$gnupg_dir" --list-keys --with-colons "$key_fpr" >/dev/null 2>&1; then
    echo "⛈️  kitty install aborted: release key fingerprint mismatch (expected $key_fpr)"
    rm -rf "$tmp_dir"
    return 1
  fi

  # fail fast unless the tarball signature is valid for that key
  if ! gpg --homedir "$gnupg_dir" --verify "$tmp_dir/${archive}.sig" "$tmp_dir/$archive" 2>&1 | grep -q "Good signature"; then
    echo "⛈️  kitty install aborted: tarball signature verification failed"
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "✨ kitty tarball signature verified (kovid goyal, $key_fpr)"

  # extract to /opt/kitty.app (self-contained: bin/, lib/, share/)
  sudo rm -rf /opt/kitty.app && sudo mkdir -p /opt/kitty.app
  sudo tar -xJf "$tmp_dir/$archive" -C /opt/kitty.app
  rm -rf "$tmp_dir"

  # expose on PATH via /usr/local/bin (precedes /usr/bin)
  sudo ln -sf /opt/kitty.app/bin/kitty /usr/local/bin/kitty
  sudo ln -sf /opt/kitty.app/bin/kitten /usr/local/bin/kitten

  echo "• kitty v${version} installed to /opt/kitty.app (kitty -> /usr/local/bin/kitty)"
  kitty --version

  # install the xterm-kitty terminfo entry via apt.
  # kitty sets TERM=xterm-kitty; tmux/ssh launched outside the kitty window need
  # this entry in the ncurses search path or they abort with "unsuitable
  # terminal: xterm-kitty". the terminfo pkg only ships the terminfo entry (not
  # the binary), so apt's version is fine even though we install kitty via tarball.
  sudo apt install kitty-terminfo -y
  echo "• kitty-terminfo installed (xterm-kitty entry for tmux/ssh)"

  # libnotify-bin provides notify-send, used by the ctrl+c copy toast
  # (copy_notify.py). without it the kitten fails with
  # "no such file or directory: notify-send" on the copy branch.
  sudo apt install -y libnotify-bin
}

configure_kitty() {
  # create kitty.conf with remote control enabled and ptyxis-parity keybinds
  # ref: https://sw.kovidgoyal.net/kitty/conf/
  # ref: https://sw.kovidgoyal.net/kitty/remote-control/
  mkdir -p ~/.config/kitty/themes

  cat > ~/.config/kitty/kitty.conf << 'EOF'
# kitty.conf
# ref: https://sw.kovidgoyal.net/kitty/conf/

# font
font_family      Hack Nerd Font Mono
font_size        12.0

# theme
include themes/desert.conf

# remote control (opt-in per terminal for security)
# socket always created; commands only accepted when launched with --allow-remote-control
# usage: kitty --allow-remote-control &
# note: abstract socket (@) lives in kernel, no filesystem path — works with flatpak
allow_remote_control no
listen_on unix:@kitty-{kitty_pid}

# window
initial_window_width  140c
initial_window_height 74c
window_padding_width 4
hide_window_decorations no
# confirm before a window with an active foreground program (nvim, claude, etc)
# is closed. -1 = confirm only when a non-shell program is active; a bare shell
# closes with no prompt. 0 = never confirm; positive N = confirm past N windows.
confirm_os_window_close -1

# cursor
cursor_shape block
cursor_blink_interval 0

# scrollback
scrollback_lines 10000

# touchpad scroll speed: kitty maps hi-res touchpad deltas 1:1 by default
# (touch_scroll_multiplier 1.0), which feels sluggish next to gnome apps that
# accelerate. bump so the laptop touchpad scrolls at a comfortable pace.
touch_scroll_multiplier 3.0

# title ownership: let the shell own the OS window title
# kitty's shell integration sets its own title, which fights our zsh
# _set_terminal_title (OSC 2, re-asserted on every precmd). no-title disables
# kitty's version so the shell is authoritative — pwd/repo:branch stays in the title.
shell_integration no-title

# keybinds (ptyxis parity — preserve muscle memory)
# clear defaults for cleaner config
clear_all_shortcuts yes

# clipboard
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
# ctrl+c: copy kitty's own selection (with toast) AND forward an unambiguous
# ctrl+shift+c downstream, so apps that own their own selection (nvim visual
# mode) can yank. the forward is the keyboard-protocol key CSI 99 ; 6 u, never
# the ^C byte — so ctrl+c still never interrupts the shell. the sole interrupt
# key stays ctrl+x. custom kitten (vs builtin copy_to_clipboard) both toasts on
# copy and gates the downstream forward on the app's kbd-protocol state.
map ctrl+c kitten copy_notify.py
# ctrl+v pastes (desktop-parity). unlike ctrl+c this is unconditional, so kitty
# grabs ctrl+v globally — the only default it shadows is shell quoted-insert
# (rare). nvim's own <C-v> paste maps stay as fallback for non-kitty terminals.
map ctrl+v paste_from_clipboard
# ctrl+x sends ^C (SIGINT) — the sole interrupt / "cancel and clear prompt" key.
# ctrl+c is copy-only (desktop parity), so interrupt lives here unambiguously.
# also the ^C escape inside TUI apps (nvim, REPLs) now that ctrl+c never passes.
map ctrl+x send_text all \x03

# tabs
map ctrl+t new_tab
map ctrl+shift+h previous_tab
map ctrl+shift+l next_tab
map ctrl+tab next_tab
map ctrl+shift+tab previous_tab
map ctrl+shift+w close_tab
map ctrl+o select_tab

# jump straight to tab N by ordinal position (ctrl+1 = first tab, etc).
# goto_tab is 1-indexed and positional, so it tracks the tab bar order, not the
# termwork --tab slug. ctrl+0 jumps to the last tab regardless of count.
map ctrl+1 goto_tab 1
map ctrl+2 goto_tab 2
map ctrl+3 goto_tab 3
map ctrl+4 goto_tab 4
map ctrl+5 goto_tab 5
map ctrl+6 goto_tab 6
map ctrl+7 goto_tab 7
map ctrl+8 goto_tab 8
map ctrl+9 goto_tab 9
map ctrl+0 goto_tab -1

# tab title: mirror the shell-set OSC title (repo:branch/subpath from
# _set_terminal_title in zshrc). {title} is that string, since shell_integration
# no-title hands title ownership to the shell. keeps tab bar == titlebar.
# {title:^14} center-pads each title to a 14-wide field so every tab is equal
# width (the `separator` style below sizes tabs to content, which would otherwise
# collapse each tab to its title length). titles longer than 14 grow as needed.
# the literal space each side guarantees ≥1 space around the title at ANY length
# (center-pad only fills titles shorter than 14; longer ones would touch the edge)
# and — since tab_separator is empty — yields a clear gap between adjacent tabs.
# note: tab bar is hidden with a single tab (kitty default), shown at 2+ tabs
tab_title_template " {title:^14} "

# tab bar style: flat, no divider. `separator` drops the default `fade` gradient
# edges; an empty tab_separator removes the character between tabs entirely, so
# the only cue for the active tab is its inverted color (set in desert.conf).
tab_bar_style separator
tab_separator ""

# scroll
map ctrl+shift+k scroll_page_up
map ctrl+shift+j scroll_page_down

# window management
# --cwd=current inherits the pwd of the active window (via shell integration)
map ctrl+backslash launch --type=os-window --cwd=current

# font size
# ctrl+0 is reassigned to goto_tab (last tab) above, so the size reset moves to
# ctrl+shift+0 to avoid the clash.
map ctrl+equal change_font_size all +1.0
map ctrl+minus change_font_size all -1.0
map ctrl+shift+0 change_font_size all 0

# key remaps
# ctrl+j sends shift+enter — lets apps that treat shift+enter specially
# (e.g. newline vs submit) be driven from the home-row ctrl+j
map ctrl+j send_key shift+enter

# misc
map ctrl+shift+f5 load_config_file
EOF

  # custom kitten that backs the `map ctrl+c` line above. two independent jobs:
  #
  # 1. copy branch — when kitty owns a mouse selection, mirror it to the
  #    clipboard and surface a desktop toast via notify-send.
  #
  # 2. forward branch — send an unambiguous ctrl+shift+c downstream so apps that
  #    own their own selection (nvim visual mode) can yank. encoded as the kitty
  #    keyboard-protocol key CSI 99 ; 6 u (\x1b[99;6u), never the ^C byte, so the
  #    shell can never SIGINT off ctrl+c. only forwarded when the focused app has
  #    the keyboard protocol on (nvim does; a bare shell prompt does not), so the
  #    shell prompt stays clean of stray escapes.
  #
  # interrupt stays entirely on ctrl+x. builtin copy_to_clipboard would skip both
  # the toast and the gated forward, so a kitten earns its keep here.
  # api refs: Window.text_for_selection(), kitty.clipboard.set_clipboard_string,
  #           Screen.current_key_encoding_flags(), Window.write_to_child()
  cat > ~/.config/kitty/copy_notify.py << 'EOF'
from kitty.boss import Boss
from kitty.clipboard import set_clipboard_string
from kittens.tui.handler import result_handler


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    # copy branch: mirror kitty's own selection to the clipboard + toast
    selection = window.text_for_selection()
    if selection:
        set_clipboard_string(selection)
        import subprocess
        subprocess.Popen(
            ['notify-send', '-t', '1200', '-a', 'kitty', 'copied to clipboard']
        )

    # forward branch: hand an unambiguous ctrl+shift+c to the focused app so it
    # can yank its own selection. gated on the kbd protocol so the shell (which
    # does not enable it) never receives the escape — no stray input, no SIGINT.
    if window.screen.current_key_encoding_flags():
        window.write_to_child(b'\x1b[99;6u')


def main(args):
    pass
EOF

  echo "• kitty config applied (~/.config/kitty/kitty.conf)"
}

configure_kitty_theme() {
  # create desert.conf theme
  # ref: https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml
  mkdir -p ~/.config/kitty/themes

  cat > ~/.config/kitty/themes/desert.conf << 'EOF'
# desert.conf
# desert palette from gogh
# ref: https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml

# interface
foreground           #ffffff
background           #333333
cursor               #ffffff
cursor_text_color    #333333
selection_foreground #333333
selection_background #555555

# 16-color palette (ANSI)
# black
color0  #4d4d4d
color8  #555555
# red
color1  #ff2b2b
color9  #ff5555
# green
color2  #98fb98
color10 #55ff55
# yellow
color3  #f0e68c
color11 #ffff55
# blue
color4  #cd853f
color12 #87ceff
# magenta
color5  #ffdead
color13 #ff55ff
# cyan
color6  #ffa0a0
color14 #ffd700
# white
color7  #f5deb3
color15 #ffffff

# tab bar
# active tab = desert-toned invert: dark text on the wheat accent (#f5deb3, the
# same light tone inactive tabs use for their text). inactive tabs blend flat into
# the bar (bg == terminal background), so the only cue for the current tab is the
# inversion — no divider, no box. active_tab_font_style plain drops kitty's default
# bold-italic on the active tab.
active_tab_foreground   #333333
active_tab_background   #f5deb3
active_tab_font_style   normal
inactive_tab_foreground #f5deb3
inactive_tab_background #333333
inactive_tab_font_style normal
EOF

  echo "• kitty desert theme applied (~/.config/kitty/themes/desert.conf)"
}

configure_kitty_icon() {
  # install custom kitty icon across all three surfaces that render it:
  #   1. dock/launcher/taskbar — the .desktop Icon= (+ Wayland app_id binding)
  #   2. window titlebar        — kitty's own ~/.config/kitty/kitty.app.png
  #      (kitty applies this at startup on X11 + wayland; compositor-permitting)
  #      ref: https://sw.kovidgoyal.net/kitty/faq/
  # these are independent — one alone leaves the other on the default icon.
  local icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
  local desktop_file="$HOME/.local/share/applications/kitty.desktop"
  local custom_icon="$HOME/git/more/dev-env-setup/assets/kitty-icon.png"

  # check if custom icon file extant in assets
  if [[ ! -f "$custom_icon" ]]; then
    echo "• kitty icon: custom icon not found at $custom_icon"
    echo "  add your custom icon there and re-run configure_kitty_icon"
    return 0
  fi

  # install into the hicolor theme under BOTH names:
  #  - kitty.png: the theme name wayland compositors (cosmic) look up from the
  #    window app_id (kitty reports app_id=kitty). without this, the app_id
  #    lookup misses and the dock falls back to the stock icon.
  #  - kitty-custom.png: the absolute path the .desktop Icon= points at.
  mkdir -p "$icon_dir"
  cp "$custom_icon" "$icon_dir/kitty.png"
  cp "$custom_icon" "$icon_dir/kitty-custom.png"

  # install kitty's native window-titlebar icon. kitty reads this file from its
  # config dir at startup and sets the per-window icon itself.
  mkdir -p "$HOME/.config/kitty"
  cp "$custom_icon" "$HOME/.config/kitty/kitty.app.png"

  # create/update desktop file with custom icon
  mkdir -p "$(dirname "$desktop_file")"
  cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Kitty
GenericName=Terminal emulator
Comment=Fast, feature-rich, GPU based terminal
TryExec=kitty
# redirect stderr to /dev/null: kitty logs [PARSE ERROR] warnings (e.g. xterm
# modifyOtherKeys) to its process stderr, shared across all os-windows in the
# instance — incl. ctrl+\ spinoffs. muted here to stop the leak into any
# terminal that launched the root kitty.
Exec=sh -c 'exec kitty 2>/dev/null'
Icon=$icon_dir/kitty-custom.png
# bind the running window to this entry so the dock honors Icon=. on wayland the
# window is matched by app_id (kitty=kitty); StartupWMClass declares that match.
StartupWMClass=kitty
Categories=System;TerminalEmulator;
EOF

  # update icon cache
  gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true

  echo "• kitty custom icon installed (dock + titlebar; logout to flush cache)"
}
