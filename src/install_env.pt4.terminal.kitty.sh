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
  # install kitty via apt (flatpak sandbox blocks remote control sockets)
  if command -v kitty &>/dev/null; then
    echo "• kitty already installed; skipped"
    return 0
  fi
  sudo apt install kitty -y
  echo "• kitty installed via apt"
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
confirm_os_window_close 0

# cursor
cursor_shape block
cursor_blink_interval 0

# scrollback
scrollback_lines 10000

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

# tabs
map ctrl+t new_tab
map ctrl+shift+h previous_tab
map ctrl+shift+l next_tab
map ctrl+shift+w close_tab
map ctrl+o select_tab

# tab title: mirror the shell-set OSC title (repo:branch/subpath from
# _set_terminal_title in zshrc). {title} is that string, since shell_integration
# no-title hands title ownership to the shell. keeps tab bar == titlebar.
# note: tab bar is hidden with a single tab (kitty default), shown at 2+ tabs
tab_title_template "{title}"

# scroll
map ctrl+shift+k scroll_page_up
map ctrl+shift+j scroll_page_down

# window management
# --cwd=current inherits the pwd of the active window (via shell integration)
map ctrl+backslash launch --type=os-window --cwd=current

# font size
map ctrl+equal change_font_size all +1.0
map ctrl+minus change_font_size all -1.0
map ctrl+0 change_font_size all 0

# misc
map ctrl+shift+f5 load_config_file
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
active_tab_foreground   #ffffff
active_tab_background   #555555
inactive_tab_foreground #f5deb3
inactive_tab_background #333333
EOF

  echo "• kitty desert theme applied (~/.config/kitty/themes/desert.conf)"
}

configure_kitty_icon() {
  # install custom kitty icon
  # creates a custom icon and updates the .desktop file
  local icon_dir="$HOME/.local/share/icons/hicolor/256x256/apps"
  local desktop_file="$HOME/.local/share/applications/kitty.desktop"
  local custom_icon="$HOME/git/more/dev-env-setup/assets/kitty-icon.png"

  # check if custom icon file extant in assets
  if [[ ! -f "$custom_icon" ]]; then
    echo "• kitty icon: custom icon not found at $custom_icon"
    echo "  add your custom icon there and re-run configure_kitty_icon"
    return 0
  fi

  # install icon
  mkdir -p "$icon_dir"
  cp "$custom_icon" "$icon_dir/kitty-custom.png"

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
Exec=kitty
Icon=$icon_dir/kitty-custom.png
Categories=System;TerminalEmulator;
EOF

  # update icon cache
  gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true

  echo "• kitty custom icon installed"
}
