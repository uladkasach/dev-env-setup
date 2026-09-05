#!/usr/bin/env bash
# .what = install the dropbox desktop client, through its own gpg-signed apt repo
# .ref  = https://www.dropbox.com/install-linux
# .why
#   - a .deb's preinst/postinst run as ROOT, and this once fetched a dated
#     .deb unverified (rule.require.verify-binary-downloads)
#   - the apt repo is a new ROUTE, not a new check bolted onto the old one —
#     no hash is expressible for the .deb, and a KEY pin re-verifies every
#     package this source will ever serve
#   - .refs = gotcha.6-3-dropbox.demo=apt-repo-not-deb
#   - it does NOT run `dropbox start -i` — that draws a GTK dialog and waits
#     for a human; the daemon starts on first launch from the app menu
#
# guarantee
#   - the key is checked against a pinned fingerprint before it is dearmored
#   - apt refuses any package this repo serves that the key does not sign
#   - idempotent: the repo file is DECLARED, never appended
#   - it DECLINES on a box with no screen

grove_provision_6_3_dropbox_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — dropbox is a desktop sync client, and"
    echo "      $GROVE_ENV_SERVER has no screen and no human to sign it in"
    return 0
  fi

  # an installed dropbox does NOT short-circuit the whole phase — this phase
  # converges an apt trust anchor, and every box that HAS dropbox got it from
  # the old unverified fetch, so an early return would skip the key on
  # exactly the boxes that need it

  # every write below is root's, and `sudo` reads a password from a
  # TERMINAL — on a duct, which is tmux, the prompt eats the next send
  pkg_assert_sudo || return 1

  # 1. the key that verifies this repo, scoped to this repo alone —
  # /etc/apt/keyrings, never /etc/apt/trusted.gpg.d, whose key may sign for
  # EVERY repo on the box
  local keyfile="/etc/apt/keyrings/dropbox.gpg"
  sudo mkdir -p /etc/apt/keyrings || return 1

  if [[ ! -f "$keyfile" ]]; then
    # the pin is a WIRE READ, the weakest tier — dropbox publishes no
    # fingerprint in its own documentation, so tier 1 is unreachable
    # (.refs = gotcha.6-3-dropbox.demo=apt-repo-not-deb)
    local keytmp
    keytmp="$(web_tempdir dropboxkey)" || return 1

    if ! web_fetch https://linux.dropbox.com/fedora/rpm-public-key.asc \
      --into "$keytmp/dropbox.asc"; then
      echo "   ✋ could not fetch the dropbox repo key" >&2
      echo "      ⇒ apt would refuse the repo as unverified, so dropbox cannot" >&2
      echo "        install at all" >&2
      echo "      ⇒ web_fetch named the wire fault above — a STALL wants a" >&2
      echo "        retry, and a 404 means dropbox moved the key" >&2
      rm -rf "$keytmp"
      return 1
    fi

    # verify BEFORE the dearmor, and BEFORE root ever sees these bytes
    if ! web_verify_gpg_fingerprints --file "$keytmp/dropbox.asc" \
      --fpr 1C61A2656FB57B7E4DE0F4C1FC918B335044912E; then
      echo "      ⇒ the key is NOT installed and the dropbox repo is NOT" >&2
      echo "        declared. a box with no dropbox beats a box whose apt trusts" >&2
      echo "        an anchor nobody vouched for" >&2
      rm -rf "$keytmp"
      return 1
    fi

    if ! gpg --dearmor --output "$keytmp/dropbox.gpg" "$keytmp/dropbox.asc"; then
      echo "   ✋ could not dearmor the dropbox repo key" >&2
      echo "      ⇒ its fingerprint already matched the pin, so these ARE the" >&2
      echo "        expected bytes — this is gpg itself" >&2
      rm -rf "$keytmp"
      return 1
    fi

    # root does exactly one op here: a `dd` of bytes already verified, so a
    # hostile key file never reaches a root process
    if ! sudo dd if="$keytmp/dropbox.gpg" of="$keyfile" status=none; then
      echo "   ✋ could not place the verified key at $keyfile" >&2
      echo "      ⇒ the key verified, so this is the filesystem or sudo" >&2
      rm -rf "$keytmp"
      return 1
    fi
    rm -rf "$keytmp"
    sudo chmod 0644 "$keyfile"
    echo "   • dropbox repo key verified against its pinned fingerprint ✔"
  fi

  # 2. the repo — declared, so a re-run cannot duplicate it. `disco` is
  # ubuntu 19.04's codename, and it is the ONLY dist dropbox publishes; do
  # NOT "correct" it to the local codename, which 404s. `arch=amd64` is
  # REQUIRED — dropbox builds no arm64
  echo "deb [arch=amd64 signed-by=$keyfile] https://linux.dropbox.com/ubuntu disco main" \
    | sudo tee /etc/apt/sources.list.d/dropbox.list >/dev/null || return 1

  # 3. the install — the ONLY step an already-present dropbox may skip. a
  # box installed by the OLD route carries a launcher NEWER than the repo's;
  # apt does not downgrade, and the skip below does not ask it to
  if command -v dropbox >/dev/null 2>&1; then
    echo "   • dropbox already present; key and repo converged, install skipped"
    return 0
  fi

  # the repo just landed, so the index must be re-read before its package is visible
  pkg_refresh || true

  pkg_install dropbox || return 1

  echo "   • dropbox installed from its signed apt repo"
  echo "     it signs in on first launch from the app menu"
}
