#!/usr/bin/env bash
######################################################################
# .what = configure ptyxis terminal keybindings and preferences
# .why  = vim-style navigation, desert theme, consistent shortcuts
#
# usage:
#   source ~/git/more/dev-env-setup/src/install_env.pt4.terminal.ptyxis.sh
#   # or via alias:
#   sync.devenv.ptyxis
#
# note: restart ptyxis after sync for keybindings to take effect
######################################################################

configure_ptyxis() {
  # restore ptyxis keybindings and preferences
  # ref: https://www.garret.is/using/ptyxis/
  #
  # howto export your current ptyxis config for backup:
  #   cat ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings/keyfile
  #
  # howto update: after changes via ptyxis preferences gui, re-export and paste below
  #
  mkdir -p ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings
  tee ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings/keyfile > /dev/null << 'EOF'
[org/gnome/Ptyxis]
profile-uuids=['48d4f1a48e2fa956aa1f108e697f9492']
default-profile-uuid='48d4f1a48e2fa956aa1f108e697f9492'
window-size=(140, 74)
use-system-font=true

[org/gnome/Ptyxis/Shortcuts]
copy-clipboard='<Shift><Control>c'
paste-clipboard='<Shift><Control>v'
select-all='<Control>a'
new-window='<Control>backslash'
close-window='<Control>q'
set-title='<Shift><Control>t'
new-tab='<Control>t'
tab-overview='<Control>o'
close-tab='<Shift><Control>w'
move-previous-tab='<Shift><Control>h'
move-next-tab='<Shift><Control>l'
scroll-page-up='<Shift><Control>k'
scroll-page-down='<Shift><Control>j'

[org/gnome/Ptyxis/Profiles/48d4f1a48e2fa956aa1f108e697f9492]
palette='Desert'
label='default'
cell-height-scale=1.0
EOF
  echo "• ptyxis config synced (restart ptyxis to apply)"
}
