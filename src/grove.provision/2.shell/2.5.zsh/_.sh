#!/usr/bin/env bash
# .what = zsh as this box's login shell, and the rc file that shapes it
# .why the login-shell switch is a PROVISION act — a fact about /etc/passwd,
#   not a file this repo writes, and it fails for a provision reason (an
#   absent `chsh`, a pam refusal)
# .why this bundle applies to a HEADLESS box — every duct lands in a login
#   shell, so a grove left on bash gets no title, no aliases, no prompt
# .why the rc is a COPY of `src/zshrc.sh`, not a heredoc — a human edits it
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
#
# 🛑 .why the read is `sudo -n test` and never a bare `[[ -f ]]`
#   - a human seat's home is `drwxr-x---` (mode 750), so a DIFFERENT seat cannot
#     traverse it. `[[ -f ]]` then answers FALSE for "i cannot see" in exactly the
#     same way it answers FALSE for "it is absent" — two states, one answer
#   - the seeder's write runs under `sudo`, which CAN reach that path
#   - ⇒ the guard is BLIND precisely where the write is POTENT, and that write is
#     `install /dev/null`, which TRUNCATES rather than creates
#
# 📜 .measured 2026-09-14, grove-ahbode-v20260901 — a ground apply read
#   `/home/camper/.zshrc` as absent (the real answer was `Permission denied`) and
#   truncated a live 39300-byte rc to 0 bytes. every login on that seat then
#   landed in a bare zsh: no starship, no aliases, no repo:branch title. the
#   binary ran and the seat's own configuration was gone
#   - ⚠️ `configure.verify`'s `zsh -n` parse check reported ✔ throughout, because
#     an EMPTY file is valid zsh. only its `cmp` row went red
#
# ⇒ the general rule this encodes: A GUARD MUST READ AT THE PRIVILEGE ITS WRITE
#   USES. where the two differ, the guard can report "absent" about a file it was
#   merely forbidden to see — and a destructive write then fires on that answer
#
# .why this also degrades correctly on a seat with NO sudo — `sudo -n test` fails
#   there, so the guard reports "no startup file", and the very next `sudo -n
#   install` fails for the identical reason. guard and write are now one
#   mechanism, so they cannot disagree
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
