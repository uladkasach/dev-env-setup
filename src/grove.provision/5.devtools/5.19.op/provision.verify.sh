#!/usr/bin/env bash
######################################################################
# .what = prove `op` RESOLVES, and that the apt anchor behind it is sane
#
# ⚠️ .`op` is invisible until the day it is needed
#   - a desktop app is missed the same day, because its icon is gone
#   - `op` surfaces only when `backup_env.sh` or `util.yubikey.ssh.sh` runs —
#     which is the day a human needs a secret restored, or a yubikey keyed
#   - ⇒ a box with no `op` reads healthy right up to that day, and no sooner
#   - 📜 that asymmetry hid this tool's absence through a whole migration
#     (`gotcha.6-5-onepassword.demo=never-installed-by-any-run`)
#
# .why the check is `command -v` and not `dpkg -s`
#   every caller reaches `op` by NAME, so the claim worth an assertion is
#   "the name resolves" — a package can be installed while its binary is
#   unreachable (`2.1.toolkit` states the same criterion)
#
# guarantee:
#   - READ-ONLY. it observes and repairs no state
######################################################################

grove_provision_5_19_op_provision_verify() {
  local failed=0

  ####################################################################
  # 1. the binary, by the name every caller uses
  ####################################################################
  if command -v op >/dev/null 2>&1; then
    echo "   • op is on PATH ✔ ($(op --version 2>/dev/null | head -1))"
  else
    echo "   ✋ op is absent from PATH" >&2
    echo "      ⇒ src/backup_env.sh and src/util.yubikey.ssh.sh each call it by" >&2
    echo "        name, and each fails at the line that reaches for a secret —" >&2
    echo "        so the defect surfaces on the day a credential is needed" >&2
    echo "      fix: rhx grove.provision --what 5.19.op --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. the repo is declared exactly ONCE, and it matches what the upsert
  #    would write TODAY
  #
  # 🛑 .count the entries — a guard on the FILE's presence is not enough
  #   a box set up by two revisions can carry two entries, and apt then
  #   prints "configured multiple times" on EVERY update. that trains a
  #   reader to skim the output where real key errors also appear
  #   (`6.2.codium` records the same measurement)
  #
  #   - no `-q`, because under `pipefail` it would exit on match and SIGPIPE
  #     (`gotcha.pipefail-grep-q`)
  ####################################################################
  local lines
  lines="$(grep -rh 'downloads.1password.com/linux/debian' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -c . || true)"

  if [[ "${lines:-0}" -eq 1 ]]; then
    ##################################################################
    # ⚠️ one entry is not the same claim as the RIGHT entry
    #   an arch bump, a moved url, or a `signed-by=` that names a key this
    #   bundle no longer places each leave exactly one line — and that line
    #   is stale. the renderer in `_.sh` is what the upsert writes, so it is
    #   what this reads (`gotcha.a-check-that-cries-wolf`, m.9)
    ##################################################################
    local want live
    want="$(grove_provision_5_19_op_repo_line 2>/dev/null)"
    live="$(grep -rh 'downloads.1password.com/linux/debian' \
      /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | head -1)"

    if [[ -n "$want" && "$live" == "$want" ]]; then
      echo "   • the 1password apt repo is declared once, as this bundle renders it ✔"
    elif [[ -z "$want" ]]; then
      echo "   🌙 the repo is declared once; its architecture could not be read,"
      echo "      so whether it matches this box is unproven"
    else
      echo "   ✋ the 1password apt repo is declared once, at a STALE line" >&2
      echo "      live: $live" >&2
      echo "      want: $want" >&2
      echo "      ⇒ apt reads the live line, so a moved url or a signed-by that" >&2
      echo "        names an absent key fails every update from now on" >&2
      echo "      fix: rhx grove.provision --what 5.19.op --mode apply" >&2
      failed=1
    fi
  elif [[ "${lines:-0}" -eq 0 ]]; then
    echo "   ✋ the 1password apt repo is NOT declared" >&2
    echo "      ⇒ op receives no updates, and a fresh box cannot install it" >&2
    echo "        at all — so this reads healthy on a box that already has op" >&2
    echo "        and fails on the next one built from scratch" >&2
    echo "      fix: rhx grove.provision --what 5.19.op --mode apply" >&2
    failed=1
  else
    echo "   ✋ the 1password apt repo is declared $lines times" >&2
    echo "      ⇒ apt complains 'configured multiple times' on EVERY update from" >&2
    echo "        now on, which trains a reader to skim the output where real key" >&2
    echo "        and signature errors also appear" >&2
    echo "      read them: grep -r 1password /etc/apt/sources.list.d/" >&2
    echo "      fix: leave ONE line, then re-run this verify" >&2
    failed=1
  fi

  ####################################################################
  # 3. the key is SCOPED, never blanket-trusted
  #
  #   a key under /etc/apt/trusted.gpg.d/ vouches for every repo apt reads,
  #   so this publisher's signature could bless a package that claims any
  #   origin at all
  ####################################################################
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
