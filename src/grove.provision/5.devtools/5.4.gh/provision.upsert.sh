#!/usr/bin/env bash
######################################################################
# .what = make the `gh` binary EXIST on this machine
#
# .the apt REPO is added here, never in the package shim
#   - gh is in NO distro repo, since github publishes its own
#   - `pkg_install` takes NAMES and cannot add a source
#   - ⇒ a bundle that needs a third-party source adds it itself
#
# .this bundle installs NO curl, though it is curl's heaviest caller
#   - to install it here would make the tree's http fetch a SIDE EFFECT of gh
#   - ⇒ twelve later bundles would inherit curl from a bundle none of them names
#   - `2.1.toolkit` owns it, which is where a base tool belongs
#
# .the key is written with `dd`, never a plain redirect
#   - the target is under /usr/share/keyrings, which needs root
#   - a `sudo curl > file` redirect is performed by the UNPRIVILEGED shell
#   - ⇒ a pipe into `sudo dd` puts the privileged half where it belongs
#
# .the mode is set explicitly to go+r
#   - apt fetches as the `_apt` user, so a root-only key reads as unsigned
#   - ⇒ the symptom reads "NO_PUBKEY" rather than "the file is 0600"
#
# refs:
#   apt — https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian-ubuntu-linux-raspberry-pi-os-apt
#
# guarantee:
#   - a present binary is left alone, so a re-run re-adds no repo and no key
#   - (`rule.require.idempotent-install-procedures`)
######################################################################

grove_provision_5_4_gh_provision_upsert() {
  ####################################################################
  # 0. already here? then the declaration holds
  ####################################################################
  if command -v gh >/dev/null 2>&1; then
    echo "   • gh already installed — no work"
    return 0
  fi

  pkg_assert_apt || return 1

  # ⚠️ every write below is root's, in /usr/share/keyrings and /etc/apt
  #   - that is a box-wide fact, so a seat with no root declines rather than fails
  #   - ground sets it with this same bundle
  #   - `provision.verify` reads the fact either way
  bundle.root.owns "the gh cli" "gh is absent from this box" || return 0

  ####################################################################
  # 1. github's release key — fetched to a file, CHECKED, then installed
  #
  # 🛑 the key is NOT piped straight into `sudo dd`
  #   - a pipe leaves no artifact, so no moment holds checkable bytes
  #   - what lands is the TRUST ANCHOR for every package from github's source
  #   - ⇒ a swapped key is not one bad install, it is every future one
  #   - ⇒ and each of those passes a clean check against the wrong anchor
  #   - (`rule.require.verify-binary-downloads`)
  #
  # .the pin, and where it came from
  #   - two primary keys, which is github's real structure and not a mistake
  #   - 📜 read off grove-ahbode-v20260811 2026-08-13, and off github's own list
  #   - ⇒ two independent channels that agree make this a sourced pin
  #   - (`gotcha.my-own-note-became-my-evidence`)
  #
  # ⚠️ the check is SET EQUALITY
  #   - a file that holds both of these AND a third key fails, deliberately
  #   - see `web_verify_gpg_fingerprints`
  ####################################################################
  local keydst="/usr/share/keyrings/githubcli-archive-keyring.gpg"
  local keytmp
  keytmp="$(web_tempdir ghkey)" || return 1

  if ! web_fetch https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    --into "$keytmp/gh.gpg"; then
    echo "   ✋ could not fetch github's cli release key" >&2
    echo "      ⇒ apt would then report github's repo as unsigned, and the error" >&2
    echo "        reads as 'NO_PUBKEY' rather than 'the key was never fetched'" >&2
    rm -rf "$keytmp"
    return 1
  fi

  if ! web_verify_gpg_fingerprints --file "$keytmp/gh.gpg" \
    --fpr 2C6106201985B60E6C7AC87323F3D4EA75716059 \
    --fpr 7F38BBB59D064DBCB3D84D725612B36462313325; then
    echo "      ⇒ gh is NOT installed, and github's source is NOT declared. that" >&2
    echo "        is the safe outcome — a box with no gh beats a box whose apt" >&2
    echo "        trusts an anchor nobody vouched for" >&2
    rm -rf "$keytmp"
    return 1
  fi

  if ! sudo dd if="$keytmp/gh.gpg" of="$keydst" status=none; then
    echo "   ✋ could not install github's cli release key to $keydst" >&2
    rm -rf "$keytmp"
    return 1
  fi
  rm -rf "$keytmp"
  echo "   • github's release key verified against its pinned fingerprints ✔"

  # .apt fetches as the `_apt` user, not root — see the header
  sudo chmod go+r "$keydst"

  ####################################################################
  # 2. the apt source, signed by exactly that key
  #   - `signed-by=$keydst` names one variable
  #   - ⇒ the path the key LANDS at and the path apt trusts cannot drift
  #   - (`rule.require.identical-bundle-composition`)
  ####################################################################
  local arch; arch="$(dpkg --print-architecture)"
  if ! echo "deb [arch=${arch} signed-by=${keydst}] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null; then
    echo "   ✋ could not declare github's apt source" >&2
    echo "      ⇒ ubuntu's archive has NO gh, so without this source the install" >&2
    echo "        below cannot find the package at all" >&2
    return 1
  fi

  if ! pkg_refresh; then
    echo "   ✋ apt could not refresh after github's source was added" >&2
    echo "      ⇒ the new source is unread, so gh is still unfindable" >&2
    echo "      read why: sudo apt-get update    # it names the source at fault" >&2
    return 1
  fi

  ####################################################################
  # 3. gh itself
  ####################################################################
  if ! pkg_install gh; then
    echo "   ✋ gh did not install" >&2
    echo "      ⇒ every github reach in this repo runs through it — the org clone," >&2
    echo "        the release watch, the pr open. on a grove that is most of the work" >&2
    echo "      read why: sudo apt-get install gh" >&2
    return 1
  fi

  echo "   • gh installed ($(gh --version 2>/dev/null | head -1))"
}
