#!/usr/bin/env bash
######################################################################
# .what = install the 1password desktop app AND its `op` cli, from 1password's
#         own apt repo
# .ref  = https://support.1password.com/install-linux/
#
# ⚠️ .BOTH packages, and `op` is the one that must not be dropped
#   - `1password` is the vault a human clicks
#   - `1password-cli` is the `op` that `backup_env.sh` and `util.yubikey.ssh.sh` call
#   - the app alone leaves both broken at the line they reach for a secret
#   - and it looks installed, because the icon is there
#
# ⚠️ .the repo line is WRITTEN, never findsert-guarded
#   - a `[ -f …1password.list ] || …` freezes that file's CONTENT once it exists
#   - a changed url, architecture, or `signed-by=` could never land
#   - ⇒ it stops the repeat, and it also stops the converge
#
# .the key is scoped by `signed-by=`, never blanket-trusted
#   - a key in `/etc/apt/trusted.gpg.d/` is trusted for EVERY repo apt reads
#   - so 1password's key could vouch for a package that claims debian
#
# guarantee
#   - idempotent: the key and repo are declared
#   - an installed package short-circuits the apt call alone
#   - it DECLINES on a box with no screen
######################################################################

grove_provision_6_5_onepassword_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo '   🌙 declined — the vault is a GUI app a human unlocks by hand, and'
    echo "      $GROVE_ENV_SERVER has no screen. op without that app is inert, so"
    echo '      neither half is owed here. a grove is handed scoped credentials'
    echo '      instead (plan.grove-credentials.md)'
    return 0
  fi

  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - on a duct, which is tmux, the prompt sits on the pane
  #   - it then eats the next command sent as its answer
  #   - `pkg_install` asserts this, so a bundle that reaches root directly must too
  pkg_assert_sudo || return 1

  ####################################################################
  # 1. the key that verifies this repo, scoped to this repo alone
  #
  #   - the filename is 1password's own, so it is not ours to pick
  ####################################################################
  local keyfile="/usr/share/keyrings/1password-archive-keyring.gpg"

  # .`gpg --dearmor` below is owned by `2.1.toolkit`
  #   - that bundle declares gnupg as a base tool for the three apt-key bundles
  #   - it is NOT re-declared here: one fact, one writer
  if [[ ! -f "$keyfile" ]]; then
    ##################################################################
    # 🛑 .the key lands as a FILE, never `web_fetch … | sudo gpg --dearmor --output`
    #   - a pipe moves the bytes wire → root with NO artifact to check in between
    #   - ⚠️ note WHICH half runs as root in that pipe: `gpg` does
    #   - so an html error page or a hostile key is parsed by a root process
    #   - here the fetch and the parse are unprivileged, and root does one `dd`
    #   - (rule.require.verify-binary-downloads)
    #
    # ⚠️ .the pin is a WIRE READ, the WEAKEST tier this repo accepts
    #   - 📜 2026-08-13: 1password's cli docs give `curl … | gpg` and no key id
    #   - so no vendor-stated value exists to compare a read against (`term=pin`)
    #   - 📜 `diagnose.apt-key-wire-read` read all four anchors in one pass
    #   - `5.4.gh` and `5.8.docker` are pinned independently, and both matched
    #   - ⇒ a real signal about the PATH, and silent about 1password's origin
    #   - ⇒ to raise the tier, re-run that diagnose from another network
    #   - ⚠️ this key carries ONE primary and NO subkey, unlike vscodium's or docker's
    #   - that diagnose prints the two apart, so a pin never lands on a subkey
    ##################################################################
    local keytmp
    keytmp="$(web_tempdir onepasswordkey)" || return 1

    if ! web_fetch https://downloads.1password.com/linux/keys/1password.asc \
      --into "$keytmp/1password.asc"; then
      echo "   ✋ could not fetch the 1password repo key" >&2
      echo "      ⇒ apt refuses the repo as unverified, so neither the app nor" >&2
      echo "        the op cli can install at all" >&2
      echo "      ⇒ web_fetch named the wire fault above — a STALL wants a" >&2
      echo "        retry, and a 404 means the key url moved" >&2
      rm -rf "$keytmp"
      return 1
    fi

    # ⚠️ verify BEFORE the dearmor, and BEFORE root ever sees it
    #   - it also catches the failure a pipe could report only as silence
    #   - bytes that are not armored ascii parse as no key at all
    if ! web_verify_gpg_fingerprints --file "$keytmp/1password.asc" \
      --fpr 3FEF9748469ADBE15DA7CA80AC2D62742012EA22; then
      echo "      ⇒ the key is NOT installed and the 1password repo is NOT" >&2
      echo "        declared. a box with no op beats a box whose apt trusts an" >&2
      echo "        anchor nobody vouched for" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! gpg --dearmor --output "$keytmp/1password.gpg" "$keytmp/1password.asc"; then
      echo "   ✋ could not dearmor the 1password repo key" >&2
      echo "      ⇒ its fingerprint already matched the pin, so these ARE the" >&2
      echo "        expected bytes — this is gpg itself" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! sudo dd if="$keytmp/1password.gpg" of="$keyfile" status=none; then
      echo "   ✋ could not place the verified key at $keyfile" >&2
      echo "      ⇒ the key verified, so this is the filesystem or sudo" >&2
      rm -rf "$keytmp"
      return 1
    fi
    rm -rf "$keytmp"
    sudo chmod 0644 "$keyfile"
    echo "   • 1password repo key verified against its pinned fingerprint ✔"
    echo "     scoped to the 1password repo alone"
  fi

  ####################################################################
  # 2. the repo — declared, so a re-run converges rather than freezes
  ####################################################################
  local arch; arch="$(dpkg --print-architecture)"
  echo "deb [arch=$arch signed-by=$keyfile] https://downloads.1password.com/linux/debian/$arch stable main" \
    | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null || return 1

  ####################################################################
  # 3. the two packages — the apt call is all an installed one may skip
  #
  #   - they are asked separately, because the app can be present while `op` is not
  #   - that is the exact state this bundle exists to end
  ####################################################################
  local want=()
  command -v 1password >/dev/null 2>&1 || want+=(1password)
  command -v op         >/dev/null 2>&1 || want+=(1password-cli)

  if [[ "${#want[@]}" -eq 0 ]]; then
    echo "   • 1password and op already present; key and repo converged"
    return 0
  fi

  # the repo may have just landed
  #   - so the index must be re-read before apt sees it
  pkg_refresh || true

  local pkg
  for pkg in "${want[@]}"; do
    pkg_install "$pkg" || return 1
  done

  echo "   • installed: ${want[*]}"
}
