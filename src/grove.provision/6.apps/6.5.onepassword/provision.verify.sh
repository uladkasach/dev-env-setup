#!/usr/bin/env bash
######################################################################
# .what
#   - prove BOTH halves landed
#   - the vault a human clicks, and the `op` a utility calls
#
# ⚠️ .`op` earns a claim of its own, and is the more important of the two
#   - the desktop app is visible, so an absent icon is noticed the same day
#   - `op` is invisible until `backup_env.sh` or `util.yubikey.ssh.sh` runs
#   - that is the day a human needs a secret restored, or a yubikey keyed
#   - ⇒ an app-only check reports a healthy box right up to that day
#   - 📜 that asymmetry hid this bundle's absence through the migration
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_6_5_onepassword_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no vault is expected"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1. the desktop vault
  ####################################################################
  if command -v 1password >/dev/null 2>&1; then
    echo "   • the 1password app is on PATH ✔"
  else
    echo "   ✋ the 1password app is absent from PATH" >&2
    echo "      ⇒ no vault to unlock, so op has no session to borrow even where" >&2
    echo "        op itself is installed" >&2
    echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
    echo "             --include onepassword" >&2
    failed=1
  fi

  ####################################################################
  # 2. `op` — the half with no icon to miss
  #
  #   - the header says why this is the claim that matters most
  ####################################################################
  if command -v op >/dev/null 2>&1; then
    echo "   • op is on PATH ✔ ($(op --version 2>/dev/null | head -1))"
  else
    echo "   ✋ op is absent from PATH" >&2
    echo "      ⇒ src/backup_env.sh and src/util.yubikey.ssh.sh each call it, and" >&2
    echo "        each fails at the line that reaches for a secret — so the defect" >&2
    echo "        surfaces on the day a credential is needed, and no sooner" >&2
    echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
    echo "             --include onepassword" >&2
    failed=1
  fi

  ####################################################################
  # 3. the repo is declared exactly ONCE, and its key is scoped
  #
  # 🛑 .count the entries — a guard on the FILE's presence is not enough
  #   - a box set up by two revisions can carry two entries
  #   - apt then prints "configured multiple times" on EVERY update
  #   - that trains a reader to skim the output where real key errors appear
  #   - (`6.2.codium` records the same measurement)
  #
  #   - no `-q`, because under `pipefail` it would exit on match and SIGPIPE
  #   - (gotcha.pipefail-grep-q)
  ####################################################################
  local lines
  lines="$(grep -rh 'downloads.1password.com/linux/debian' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -c . || true)"

  if [[ "${lines:-0}" -eq 1 ]]; then
    echo "   • the 1password apt repo is declared once ✔"
  elif [[ "${lines:-0}" -eq 0 ]]; then
    echo "   🌙 1password is installed, but its apt repo is no longer declared"
    echo "      it will not receive updates. re-apply to restore the repo"
  else
    echo "   ✋ the 1password apt repo is declared $lines times" >&2
    echo "      ⇒ apt complains 'configured multiple times' on EVERY update from" >&2
    echo "        now on, which trains a reader to skim the output where real key" >&2
    echo "        and signature errors also appear" >&2
    echo "      read them: grep -r 1password /etc/apt/sources.list.d/" >&2
    echo "      fix: leave ONE line, then re-run this verify" >&2
    failed=1
  fi

  if [[ -f /etc/apt/trusted.gpg.d/1password.gpg ]]; then
    echo "   ✋ a 1password key sits in /etc/apt/trusted.gpg.d/" >&2
    echo "      ⇒ a key there is trusted for EVERY apt repo, so this publisher's" >&2
    echo "        signature can vouch for a package that names ANY origin —" >&2
    echo "        debian, ubuntu, docker, github" >&2
    echo "      fix: sudo rm -f /etc/apt/trusted.gpg.d/1password.gpg" >&2
    failed=1
  fi

  return $failed
}
