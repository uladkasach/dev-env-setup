#!/usr/bin/env bash
# .what = zsh as this box's login shell, and the rc file that shapes it
# .why the login-shell switch is a PROVISION act — a fact about /etc/passwd,
#   not a file this repo writes, and it fails for a provision reason (an
#   absent `chsh`, a pam refusal)
# .why this bundle applies to a HEADLESS box — every duct lands in a login
#   shell, so a grove left on bash gets no title, no aliases, no prompt
# .why the rc is a COPY of `src/grove.provision/2.shell/2.5.zsh/zshrc.sh`, not a heredoc — a human edits it
#   as a file, with syntax highlight and a diff history
# guarantee: identical on every machine (rule.require.identical-bundle-composition)

# .what = _grove_provision_2_5_zsh_human_seats — every HUMAN login, one per line
# .why one declaration for both phases (rule.forbid.two-writers-on-one-artifact)
# .why a UID FLOOR of 1000, not a name — debian/ubuntu reserve uid < 1000
#   for system accounts, and the bundle tree names no seat
# .why the shell filter — a `nologin`/`false` seat is DECLARED un-loginable
_grove_provision_2_5_zsh_human_seats() {
  getent passwd \
    | awk -F: '$3 >= 1000 && $1 != "nobody" && $6 != "" \
                && $7 !~ /(nologin|false|sync)$/ { print $1 }'
}

# .what = _grove_provision_2_5_zsh_seat_has_startup_file — does this seat already
#   hold ANY zsh startup file, READ at the same privilege the seeder's write uses?
# .why
#   - 🛑 `sudo -n test`, never a bare `[[ -f ]]` — a 750 home answers "absent"
#     for "i cannot see", and the `sudo install /dev/null` write then TRUNCATES
#   - with no sudo, the guard and the write fail for one reason, so they agree
# .refs = gotcha.2-5-zsh.demo=login-shell-record-seat-gap, m4 — a live rc cut to 0
_grove_provision_2_5_zsh_seat_has_startup_file() {
  local seat_home="$1" f
  for f in .zshenv .zprofile .zshrc .zlogin; do
    if [[ "$seat_home" == "$HOME" ]]; then
      [[ -f "$seat_home/$f" ]] && return 0
      continue
    fi
    sudo -n test -f "$seat_home/$f" 2>/dev/null && return 0
  done
  return 1
}

grove_provision_2_5_zsh() {
  bundle.upgrade 2.5.zsh.provision.upsert
  bundle.upgrade 2.5.zsh.provision.verify
  bundle.upgrade 2.5.zsh.configure.upsert
  bundle.upgrade 2.5.zsh.configure.verify
}
