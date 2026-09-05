#!/usr/bin/env bash
# .what = install the protonvpn client, through its own apt repo
# .ref  = https://protonvpn.com/support/linux-ubuntu-vpn-setup/
# .why
#   - a release .deb FIRST, then apt — the .deb holds no client, only proton's
#     apt repo and release key, so `apt upgrade` keeps the client current
#   - the appindicator packages — proton's client minimizes to a tray icon,
#     and without the indicator extension the window vanishes with no way
#     back, which reads as a crash rather than as a minimize
#   - .refs = gotcha.6-4-protonvpn.demo=deb-repo-two-defects
#
# guarantee
#   - idempotent: an installed client short-circuits, and the .deb re-applies clean
#   - it DECLINES on a box with no screen

grove_provision_6_4_protonvpn_provision_upsert() {
  # the pin reaches TIER 1 — proton publishes this exact file's sha256 in its
  # setup docs, separate from the download. the three locals are named
  # `protonvpn_*` and the url is spelled literal text, since
  # `prove.sha256-pins-bite` reads them by name and substitutes the version
  # into the url (rule.require.identical-bundle-composition)
  # .refs = gotcha.6-4-protonvpn.demo=deb-repo-two-defects
  local protonvpn_version="1.0.8"
  local protonvpn_sha256="0b14e71586b22e498eb20926c48c7b434b751149b1f2af9902ef1cfe6b03e180"
  local protonvpn_url="https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_${protonvpn_version}_all.deb"

  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — this is the DESKTOP client, and $GROVE_ENV_SERVER has"
    echo "      no screen. a grove reaches private hosts through its own duct,"
    echo "      not through a vpn a human clicks"
    return 0
  fi

  # `protonvpn-app` is the desktop client's own binary; `protonvpn` belongs to
  # a DIFFERENT package (the cli), so a test for it would never short-circuit
  # here and would ✋ on a healthy box (.refs = gotcha.6-4-protonvpn.demo=deb-repo-two-defects)
  if command -v protonvpn-app >/dev/null 2>&1; then
    echo "   • protonvpn desktop client already installed; skipped"
    return 0
  fi

  # every write below is root's, and `sudo` reads a password from a
  # TERMINAL — on a duct, which is tmux, the prompt eats the next send
  pkg_assert_sudo || return 1

  local deb
  deb="$(basename "$protonvpn_url")"

  # a PRIVATE temp dir — a .deb's maintainer procedures run AS ROOT, so a
  # fixed `/tmp/$deb` in a 1777 dir would let another seat's package install
  # here first; `web_tempdir` returns a 0700 dir with a random suffix
  local tmp_dir
  tmp_dir="$(web_tempdir protonvpn)" || return 1
  local tmp="$tmp_dir/$deb"

  if ! web_fetch "$protonvpn_url" --into "$tmp"; then
    echo "   ✋ could not download the protonvpn repo package $protonvpn_version" >&2
    echo "      ⇒ a 22 has TWO causes and different repairs: the VERSION aged" >&2
    echo "        out (bump it AND its sha256 together), or the HOST moved (the" >&2
    echo "        url is stale, the version is fine)" >&2
    echo "      fix: read https://protonvpn.com/support/official-linux-vpn-ubuntu/" >&2
    echo "        for the current url, version, AND published sha256" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # verify BEFORE apt sees it — a .deb's preinst/postinst run as ROOT, so an
  # unverified package here is arbitrary root code
  if ! web_verify_sha256 --file "$tmp" --sha256 "$protonvpn_sha256"; then
    echo "      ⇒ protonvpn is NOT installed, and the package is discarded" >&2
    echo "        unopened. a box with no vpn client beats a box that ran a" >&2
    echo "        .deb's root maintainer procedures on bytes nobody vouched for" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • protonvpn repo package $protonvpn_version verified against its pinned sha256 ✔"

  if ! pkg_apt apt-get install -y "$tmp"; then
    echo "   ✋ apt refused the protonvpn repo package at $tmp" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"

  # the repo just landed, so the index must be re-read before its client is visible
  pkg_refresh || true

  # `proton-vpn-gnome-desktop` is the real name — `protonvpn` names no
  # package proton serves at all, so that install could never have
  # succeeded. it sits in `binary-all`, not `binary-amd64`, since the client
  # is arch-independent (.refs = gotcha.6-4-protonvpn.demo=deb-repo-two-defects)
  pkg_install proton-vpn-gnome-desktop || return 1

  # the tray icon — see the header for why an absent indicator reads as a crash
  pkg_install gnome-shell-extension-appindicator || true
  pkg_install gir1.2-appindicator3-0.1 || true

  echo "   • protonvpn installed"
}
