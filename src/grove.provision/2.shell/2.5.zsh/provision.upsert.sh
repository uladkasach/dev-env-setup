#!/usr/bin/env bash
######################################################################
# .what = make zsh EXIST, and make it this user's login shell
#
# .why there is a `.bash_profile` FALLBACK and not just a `chsh` call
#   - `chsh` writes /etc/passwd and needs the box's own auth
#   - on some images it is absent
#   - on others pam refuses it for a user with no password
#   - that is every cloud box that authenticates by key alone
#   - ⇒ where the record cannot change, an interactive bash login hands OFF to zsh
#
# .why the fallback tests `case $- in *i*` and not `[[ -t 0 ]]`
#   - it must fire for an INTERACTIVE login and never for an unattended one
#   - `$-` holds bash's own flags, and `i` is bash's own answer to "am i interactive"
#   - ⇒ it is the shell's fact, not a guess from a tty
#   - an `exec zsh` in a non-interactive shell replaces a live procedure mid-flight
#   - that breaks every `ssh box 'command'` and every scp
#
# .why the fallback is GUARDED by a grep for its own line
#   - `>>` appends, so an unguarded write stacks a new `exec zsh` on every run
#   - a .bash_profile with five of them still works
#   - ⇒ that is what makes it rot unnoticed (rule.require.idempotent-install-procedures)
#
# guarantee:
#   - idempotent: apt reports a present package
#   - idempotent: the chsh re-sets the same value
#   - idempotent: the profile hook is guarded by a grep for its own line
######################################################################

grove_provision_2_5_zsh_provision_upsert() {
  ####################################################################
  # 1. the binary
  ####################################################################
  if ! pkg_install zsh; then
    echo "   ✋ zsh did not install" >&2
    echo "      ⇒ the configure phase copies an rc file for a shell that is not" >&2
    echo "        here, and the login-shell switch below has no target" >&2
    echo "      read why: sudo apt-get install zsh" >&2
    return 1
  fi

  local zsh_bin; zsh_bin="$(command -v zsh)"
  if [[ -z "$zsh_bin" ]]; then
    echo "   ✋ zsh installed but is not on PATH" >&2
    echo "      ⇒ chsh needs an absolute path, and /etc/shells is matched against" >&2
    echo "        it, so a login-shell switch cannot be made without one" >&2
    return 1
  fi

  # .what = 2. the record, for EVERY seat on the box — not just this one
  # .why a write of `$USER` alone makes a one-command provision impossible — the
  #   seat that could write it is not the seat that needs it, and the constrained
  #   seat needs what it cannot grant itself, so the grant belongs to the seat that
  #   CAN, as a bundle (rule.require.seam-claims-have-an-owner, rule.require.one-command-provision)
  # .why enumerate rather than name `camper` and `ground` — the bundle tree holds
  #   no seat names, and /etc/passwd already says what a HUMAN seat is
  # .refs = gotcha.2-5-zsh.demo=login-shell-record-seat-gap
  local seats; seats="$(_grove_provision_2_5_zsh_human_seats)"

  # .what = 2a. a seat whose record says zsh MUST hold a zsh startup file
  # 🛑 a record that names zsh with no startup file is a one-command blocker — the
  #   record write below hands a seat a shell it cannot yet open, and its first-run
  #   wizard eats the next command sent down the duct (`term=eat`)
  # .why the GROUND seat owes this, not the seat that hits it — the camper cannot
  #   converge its own rc until a command reaches it, and no command can reach it
  #   until an rc exists (rule.require.seam-claims-have-an-owner)
  # .why an EMPTY `.zshrc` rather than a fresh artifact — `2.5.zsh.configure.upsert`
  #   copies `src/zshrc.sh` over it on that seat's own apply, so this seeds an
  #   artifact the SAME bundle finishes (rule.forbid.two-writers-on-one-artifact)
  # .why it sweeps EVERY seat, not only the records this run writes — a box left
  #   half-converged by an earlier apply would never be repaired otherwise
  # .refs = gotcha.2-5-zsh.demo=login-shell-record-seat-gap
  local seat seat_home seat_group seeded=""
  while IFS= read -r seat; do
    [[ -n "$seat" ]] || continue

    seat_home="$(getent passwd "$seat" 2>/dev/null | cut -d: -f6)"
    [[ -n "$seat_home" && -d "$seat_home" ]] || continue

    # ANY one of zsh's four startup files suppresses the first-run wizard
    if [[ -f "$seat_home/.zshenv" || -f "$seat_home/.zprofile" \
       || -f "$seat_home/.zshrc"  || -f "$seat_home/.zlogin" ]]; then
      continue
    fi

    # this seat's own home needs no privilege
    if [[ "$seat_home" == "$HOME" ]]; then
      : > "$seat_home/.zshrc" 2>/dev/null && seeded="${seeded}${seat} "
      continue
    fi

    # another seat's home needs root, and `-n` so it can never prompt
    seat_group="$(id -gn "$seat" 2>/dev/null || echo "$seat")"
    sudo -n install -m 644 -o "$seat" -g "$seat_group" /dev/null \
      "$seat_home/.zshrc" >/dev/null 2>&1 && seeded="${seeded}${seat} "
  done <<< "$seats"

  [[ -n "$seeded" ]] && \
    echo "   • seeded an empty ~/.zshrc for: ${seeded% } — without one, zsh's" && \
    echo "     first-run wizard opens on that seat's duct pane and eats the" &&  \
    echo "     first command sent to it"

  local shell_now unset_seats=""
  while IFS= read -r seat; do
    [[ -n "$seat" ]] || continue
    shell_now="$(getent passwd "$seat" 2>/dev/null | cut -d: -f7)"
    [[ "$shell_now" == "$zsh_bin" ]] && continue
    unset_seats="${unset_seats}${seat} "
  done <<< "$seats"

  if [[ -z "$unset_seats" ]]; then
    echo "   • every seat's login shell is already zsh ($zsh_bin)"
    return 0
  fi

  # .what = 3. the record write — `sudo -n`, so it can NEVER prompt
  # .why a bare `sudo` on a seat without NOPASSWD reads the TERMINAL for a
  #   password — a duct is tmux, so that prompt sits on the pane and eats the next
  #   command sent down; the provision does not merely fail, it corrupts the
  #   command stream (rule.forbid.tty-as-a-proxy-for-a-human). `-n` turns that into
  #   an immediate non-zero, which the decline below handles
  local wrote="" refused=""
  if command -v chsh >/dev/null 2>&1; then
    for seat in $unset_seats; do
      if sudo -n chsh -s "$zsh_bin" "$seat" >/dev/null 2>&1; then
        wrote="${wrote}${seat} "
      else
        refused="${refused}${seat} "
      fi
    done
  else
    refused="$unset_seats"
  fi

  [[ -n "$wrote" ]] && echo "   • login shell set to zsh for: ${wrote% }"

  if [[ -z "$refused" ]]; then
    return 0
  fi

  # .what = 4. a refused record — a ✋ on THIS seat, and the fallback is a mitigation
  # .why the `.bash_profile` hand-off reaches a human's login only — `ssh seat
  #   '<cmd>'`, a cron, and a jest child all stay `bash -c` and read NO startup
  #   file, so the hand-off never clears this ✋ for the callers a grove runs on
  #   (gotcha.2-5-zsh.demo=login-shell-record-seat-gap, m3)
  # .why this ✋ names the SEAT that owes the fix, not the seat that hit it — the
  #   camper cannot write its own record, so the fix is "the ground seat's apply
  #   has not run, or ran without NOPASSWD" (rule.require.seam-claims-have-an-owner)
  # .refs = gotcha.2-5-zsh.demo=login-shell-record-seat-gap
  echo "   ✋ the login-shell record is still bash for: ${refused% }" >&2
  echo "      ⇒ \`ssh <seat> '<cmd>'\` runs the RECORD, so a bash record means" >&2
  echo "        \`bash -c\` — which reads no startup file at all. every" >&2
  echo "        program-borne call onto that seat gets a bare PATH, so rhx," >&2
  echo "        pnpm, and node are absent from it" >&2
  echo "      ⇒ this seat cannot write the record; the seat WITH sudo can, and" >&2
  echo "        writes it for every seat on the box" >&2
  echo "      fix: run this bundle from the seat that holds NOPASSWD sudo —" >&2
  echo "        ssh <grove>.ground" >&2
  echo "        rhx grove.provision --what 2.5.zsh --mode apply" >&2

  # .what = the hand-off stays as a MITIGATION for the human's login only
  # .why it does not clear the ✋ above — it cannot reach the callers that ✋ is about
  if grep -qF 'command -v zsh >/dev/null && exec zsh' "$HOME/.bash_profile" 2>/dev/null; then
    echo "      • (a zsh hand-off is declared in ~/.bash_profile, so a HUMAN's"
    echo "        login still lands in zsh — that is a mitigation, not the fix)"
    return 1
  fi

  # `case $- in *i*` is bash's OWN interactive flag — see the block above
  if printf '\n# hand off an interactive login to zsh (the record names bash)\ncase $- in *i*) command -v zsh >/dev/null && exec zsh ;; esac\n' \
    >> "$HOME/.bash_profile" 2>/dev/null; then
    echo "      • (a zsh hand-off was declared in ~/.bash_profile, so a HUMAN's"
    echo "        login still lands in zsh — that is a mitigation, not the fix)"
  fi

  return 1
}
