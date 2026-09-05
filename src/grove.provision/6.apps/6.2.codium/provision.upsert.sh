#!/usr/bin/env bash
######################################################################
# .what = install vscodium from its own apt repo
# .ref  = https://vscodium.com/
#
#   - vscodium is the same editor, from the same source, with the brand marks cut
#
# ⚠️ .the key lands in /etc/apt/keyrings, NOT /etc/apt/trusted.gpg.d
#   - a key under `trusted.gpg.d` may sign for EVERY repo on the box
#   - so a compromised vscodium key could serve a replacement `openssh-server`
#   - a keyfile named by one `signed-by=` line is trusted for that one repo alone
#
# ⚠️ .the sources line is WRITTEN, never appended
#   - a `tee --append` adds the same repo again on every run
#   - apt then warns about a duplicate entry on every `apt update`, forever
#
# guarantee
#   - idempotent: an installed codium short-circuits the install alone
######################################################################

grove_provision_6_2_codium_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — codium is a GUI editor, and $GROVE_ENV_SERVER has no"
    echo "      screen. a grove edits through nvim over its duct (4.5.nvim)"
    return 0
  fi

  ####################################################################
  # 🛑 .an installed codium skips the apt INSTALL alone, never this phase
  #   - a `command -v codium && return 0` makes the key repair below UNREACHABLE
  #   - the flaw is a key at `/etc/apt/trusted.gpg.d/vscodium.gpg`, trusted for EVERY repo
  #   - a box that carries it HAS codium, so an early return skips exactly those
  #   - worse, `provision.verify` asserts the repo LINE and not the key's location
  #   - ⇒ this phase converges the key and the repo on every run
  ####################################################################

  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - on a duct, which is tmux, the prompt sits on the pane
  #   - it then eats the next command sent as its answer
  #   - `pkg_install` asserts this, so a bundle that reaches root directly must too
  pkg_assert_sudo || return 1

  ####################################################################
  # 1. the key that verifies this repo, scoped to this repo alone
  ####################################################################
  local keyfile="/etc/apt/keyrings/vscodium.gpg"
  sudo mkdir -p /etc/apt/keyrings || return 1

  # .`gpg --dearmor` below is owned by `2.1.toolkit`
  #   - that bundle declares gnupg as a base tool for the three apt-key bundles
  #   - it is NOT re-declared here: one fact, one writer
  if [[ ! -f "$keyfile" ]]; then
    ##################################################################
    # 🛑 .the key lands as a FILE, never `web_fetch … | gpg --dearmor | sudo tee`
    #   - a pipe moves the bytes wire → root with NO artifact to check in between
    #   - that is the `curl … | sh` shape, and it is worse here
    #   - an apt anchor verifies EVERY package this source will ever serve
    #   - ⇒ the fingerprint is checked on the file, then it is dearmored
    #   - (rule.require.verify-binary-downloads)
    #
    # ⚠️ .the pin is a WIRE READ, the WEAKEST tier this repo accepts
    #   - 📜 2026-08-13: vscodium.com states the apt commands and no key id
    #   - so no vendor-stated value exists to compare a read against (`term=pin`)
    #   - 📜 `diagnose.apt-key-wire-read` read all four anchors in one pass
    #   - `5.4.gh` and `5.8.docker` are pinned independently, and both matched
    #   - ⇒ a real signal about the PATH, and silent about vscodium's origin
    #   - it catches every LATER substitution, the real threat against `raw/master`
    #   - ⇒ to raise the tier, re-run that diagnose from another network
    ##################################################################
    local keytmp
    keytmp="$(web_tempdir codiumkey)" || return 1

    if ! web_fetch https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg \
      --into "$keytmp/pub.gpg"; then
      echo "   ✋ could not fetch the vscodium repo key" >&2
      echo "      ⇒ apt would refuse the repo as unverified, so codium cannot" >&2
      echo "        install at all" >&2
      echo "      ⇒ web_fetch named the wire fault above — a STALL wants a" >&2
      echo "        retry, and a 404 means the raw/master url moved" >&2
      rm -rf "$keytmp"
      return 1
    fi

    # ⚠️ verify BEFORE the dearmor, and BEFORE root ever sees it
    #   - it also catches the failure a pipe could report only as silence
    #   - a 'raw/master' url that starts to serve html parses as no key at all
    if ! web_verify_gpg_fingerprints --file "$keytmp/pub.gpg" \
      --fpr 1302DE60231889FE1EBACADC54678CF75A278D9C; then
      echo "      ⇒ the key is NOT installed and the vscodium repo is NOT" >&2
      echo "        declared. a box with no codium beats a box whose apt trusts" >&2
      echo "        an anchor nobody vouched for" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! gpg --dearmor --output "$keytmp/vscodium.gpg" "$keytmp/pub.gpg"; then
      echo "   ✋ could not dearmor the vscodium repo key" >&2
      echo "      ⇒ its fingerprint already matched the pin, so these ARE the" >&2
      echo "        expected bytes — this is gpg itself" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! sudo dd if="$keytmp/vscodium.gpg" of="$keyfile" status=none; then
      echo "   ✋ could not place the verified key at $keyfile" >&2
      echo "      ⇒ the key verified, so this is the filesystem or sudo" >&2
      rm -rf "$keytmp"
      return 1
    fi
    rm -rf "$keytmp"
    sudo chmod 0644 "$keyfile"
    echo "   • vscodium repo key verified against its pinned fingerprint ✔"
  fi

  ####################################################################
  # 2. sweep the LEGACY key, which is the actual security repair
  #
  # ⚠️ .this removal is the point of the whole phase
  #   - a key in `/etc/apt/trusted.gpg.d/` is trusted for EVERY repo apt reads
  #   - so vscodium's key can vouch for a package that claims debian or docker
  #   - the scoped keyfile above does NOT undo that
  #   - it is safe to REMOVE, since step 1 re-declared the same key, scoped
  ####################################################################
  local keyfile_legacy="/etc/apt/trusted.gpg.d/vscodium.gpg"
  if [[ -f "$keyfile_legacy" ]]; then
    if sudo rm -f "$keyfile_legacy"; then
      echo "   • swept the legacy key from /etc/apt/trusted.gpg.d/ ✔"
      echo "     ⇒ it was trusted for EVERY apt repo; the scoped keyfile above"
      echo "       now binds it to the vscodium repo alone"
    else
      echo "   ✋ could not remove $keyfile_legacy" >&2
      echo "      ⇒ until it is gone this key vouches for EVERY apt repo, so a" >&2
      echo "        package claiming any origin can be signed by it" >&2
      echo "      fix: sudo rm -f $keyfile_legacy" >&2
      return 1
    fi
  fi

  ####################################################################
  # 3. the repo — declared, so a re-run cannot duplicate it
  ####################################################################
  echo "deb [signed-by=$keyfile] https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main" \
    | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null || return 1

  ####################################################################
  # 4. the install — the ONLY step an already-present codium may skip
  ####################################################################
  if command -v codium >/dev/null 2>&1; then
    echo "   • codium already present; key and repo converged, install skipped"
    return 0
  fi

  pkg_refresh || true
  pkg_install codium || return 1

  echo "   • codium installed"
}
