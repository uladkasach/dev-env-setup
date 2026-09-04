#!/usr/bin/env bash
# .what
#   - make the pinned kitty build EXIST at /opt/kitty.app
#   - verify it by both a sha256 and kovid goyal's gpg signature
#   - then expose it on PATH
# .why
#   - ubuntu noble ships kitty ~0.32, which predates the fix for kitty#7136 —
#     that kitty sent spurious key-RELEASE events, so nvim doubled every Enter
#   - the flatpak's sandbox blocks the remote-control socket every termwork
#     skill here rests on `kitten @`
#   - the check reads the VERSION, since presence alone passes the broken 0.32
#   - two independent checks (sha256 + gpg) so no single compromised source
#     forges a tarball past this bundle (rule.require.verify-binary-downloads)
#
# .how to bump: update `version` and `sha256` together, from github's api:
#   gh api -X GET repos/kovidgoyal/kitty/releases/tags/v<VER> \
#     --jq '.assets[] | select(.name|endswith("x86_64.txz")) | .digest'
#
# guarantee
#   - idempotent: at the pinned version this is a no-op
#   - the extract happens only after both checks pass
#   - the temp dir is removed on every exit path

grove_provision_4_3_2_emulator_provision_upsert() {
  # the pin is named `kitty_*` and the url is spelled out, never built from a
  # `$base` — `prove.sha256-pins-bite` reads `<name>_version`/`_sha256`/`_url`
  # and substitutes `${kitty_version}` as literal text
  # (rule.require.identical-bundle-composition)
  local kitty_version="0.47.4"
  local kitty_sha256="bc230142b2bd27f2a4bf1b1b67575f3d397a4ea2cc83f4ac2b912c306a939693"
  local kitty_url="https://github.com/kovidgoyal/kitty/releases/download/v${kitty_version}/kitty-${kitty_version}-x86_64.txz"

  local version="$kitty_version"
  local sha256="$kitty_sha256"
  local url="$kitty_url"
  local archive; archive="$(basename "$kitty_url")"
  local sig_url="${kitty_url}.sig"

  # a PRIVATE temp dir — the tarball, its .sig, AND the pinned key all land
  # here, and a seat that owned a fixed 1777 path could swap all three
  # (src/grove.web.sh)
  local tmp_dir
  tmp_dir="$(web_tempdir kitty)" || return 1

  # kitty signs every release with kovid goyal's key, fingerprint pinned so a
  # swapped key cannot slip a forged tarball past
  # ref: https://github.com/kovidgoyal/kitty/discussions/5942
  local key_url="https://github.com/kovidgoyal.gpg"
  local key_fpr="3CE1780F78DD88DF45194FD706BC317B515ACE7C"

  # already at the pinned version? the declaration holds
  local have=""
  have="$(kitty --version 2>/dev/null | awk '{print $2}')"
  if [[ "$have" == "$version" ]]; then
    echo "   • kitty $version already installed — no work"
    return 0
  fi
  [[ -n "$have" ]] && echo "   • kitty $have installed, want $version — re-provision"

  # every write below lands OUTSIDE every $HOME; a seat with no root declines
  bundle.root.owns "the pinned kitty build" \
    "want v${version}; this box serves ${have:-（no kitty）}" || return 0

  # 1. drop the apt-managed binary, so /usr/bin/kitty cannot shadow the
  # tarball. `kitty-terminfo` is left alone — `4.3.1.terminfo` owns that claim
  pkg_apt apt-get remove -y kitty 2>/dev/null || true

  # 2. fetch the tarball and its detached signature into the fresh, private
  # temp dir (no rm -rf/mkdir reset needed)
  if ! web_fetch "$url" --into "$tmp_dir/$archive"; then
    echo "   ✋ could not download the kitty tarball" >&2
    echo "      ⇒ url: $url" >&2
    echo "      ⇒ no extract was attempted, so the extant kitty (if any) is untouched" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! web_fetch "$sig_url" --into "$tmp_dir/${archive}.sig"; then
    echo "   ✋ could not download the kitty signature" >&2
    echo "      ⇒ the tarball is present but UNVERIFIABLE, so it is discarded" >&2
    echo "      ⇒ an unsigned install is refused on purpose; a forged tarball is" >&2
    echo "        exactly what this bundle's two checks exist to catch" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # 3. check one — the pinned sha256, a constant in this file so it bites
  # regardless of who owns the temp dir (rule.forbid.fixed-paths-in-a-shared-tmp)
  if ! web_verify_sha256 --file "$tmp_dir/$archive" --sha256 "$sha256"; then
    echo "      ⇒ kitty aborted; see .how in this file's header for the bump" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # 4. check two — the gpg signature, read into an isolated gpg store so a
  # third-party key never touches the human's own keystore. gpg is declared
  # once, in 2.1.toolkit, ahead of every apt-key bundle that needs it
  local gnupg_dir="$tmp_dir/gnupg"
  mkdir -p "$gnupg_dir" && chmod 700 "$gnupg_dir"

  if ! web_fetch "$key_url" --into "$tmp_dir/kovid.gpg"; then
    echo "   ✋ could not download the kitty release key" >&2
    echo "      ⇒ url: $key_url" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  gpg --homedir "$gnupg_dir" --import "$tmp_dir/kovid.gpg" >/dev/null 2>&1

  # the IMPORT is judged apart from the FINGERPRINT — one combined
  # `gpg --list-keys` read every failure as a security mismatch, when an
  # absent gpg or unwritable homedir raises it just as easily
  # (gotcha.a-check-that-cries-wolf-gets-silenced)
  if ! gpg --homedir "$gnupg_dir" --list-keys --with-colons >/dev/null 2>&1; then
    echo "   ✋ kitty aborted: the release key could not be READ back" >&2
    echo "      ⇒ this is NOT a fingerprint mismatch — no key reached gpg's store," >&2
    echo "        so no comparison was ever made" >&2
    echo "      ⇒ usual causes: gpg absent or broken, or $tmp_dir unwritable" >&2
    echo "      read why: gpg --homedir $gnupg_dir --import $tmp_dir/kovid.gpg" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! gpg --homedir "$gnupg_dir" --list-keys --with-colons "$key_fpr" >/dev/null 2>&1; then
    echo "   ✋ kitty aborted: release key fingerprint MISMATCH" >&2
    echo "      expected: $key_fpr" >&2
    echo "      ⇒ a key WAS imported and it is not the pinned one, so a signature" >&2
    echo "        made with it proves no fact about this tarball" >&2
    echo "      ⇒ url: $key_url" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # the signature must be bound to the PINNED key, not merely be "good" — a
  # bare "Good signature" grep matches any key gpg imported, so a real key
  # served beside a forged one would pass both the containment gate above and
  # a bare-good-signature grep. `--status-fd 1` names the actual signer via
  # `VALIDSIG <fpr>`, and the pinned fingerprint must appear on that line.
  # not `web_verify_gpg_signature` here — it does SET EQUALITY, and
  # `key_url` serves every key that github account holds, so a blind switch
  # would halt an install that works; a per-key `--fpr` pin is owed later.
  # `grep` carries no `-q` — under pipefail, `-q` exits on match and SIGPIPEs
  # gpg, so the pipeline reports 141 and a good signature reads as bad
  # (gotcha.pipefail-grep-q)
  if ! gpg --homedir "$gnupg_dir" --status-fd 1 --batch \
        --verify "$tmp_dir/${archive}.sig" "$tmp_dir/$archive" 2>/dev/null \
    | grep "^\[GNUPG:\] VALIDSIG .*$key_fpr" >/dev/null; then
    echo "   ✋ kitty aborted: tarball signature verification FAILED" >&2
    echo "      expected a VALIDSIG from: $key_fpr" >&2
    echo "      ⇒ the sha256 matched but the pinned key did NOT sign these bytes." >&2
    echo "        note this is stricter than 'a good signature': a signature from" >&2
    echo "        ANY OTHER key in the downloaded key file is refused here, because" >&2
    echo "        a real key served beside a forged one is the cheap attack" >&2
    echo "      ⇒ read the signer it actually names —" >&2
    echo "        gpg --homedir $gnupg_dir --status-fd 1 --verify \\" >&2
    echo "          $tmp_dir/${archive}.sig $tmp_dir/$archive" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • tarball verified — sha256 + gpg VALIDSIG (kovid goyal, $key_fpr) ✔"

  # 5. extract to /opt/kitty.app (self-contained: bin/, lib/, share/)
  sudo rm -rf /opt/kitty.app && sudo mkdir -p /opt/kitty.app
  if ! sudo tar -xJf "$tmp_dir/$archive" -C /opt/kitty.app; then
    echo "   ✋ could not extract the kitty tarball to /opt/kitty.app" >&2
    echo "      ⇒ /opt/kitty.app may now be PARTIAL. the next run removes the dir" >&2
    echo "        first and re-extracts, so a retry repairs it" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"

  # 6. expose on PATH via /usr/local/bin, which precedes /usr/bin. kitten is
  # linked too — every termwork skill here drives `kitten @`
  sudo ln -sf /opt/kitty.app/bin/kitty /usr/local/bin/kitty
  sudo ln -sf /opt/kitty.app/bin/kitten /usr/local/bin/kitten

  echo "   • kitty v${version} installed to /opt/kitty.app"

  # 7. libnotify-bin — copy_notify.py calls notify-send on its copy branch;
  # absent it, the ctrl+c copy toast fails and reads as a broken keybind
  if ! pkg_install libnotify-bin; then
    echo "   ✋ libnotify-bin did not install" >&2
    echo "      ⇒ kitty itself is fine; the ctrl+c copy TOAST will fail with" >&2
    echo "        'no such file or directory: notify-send', which reads as a broken" >&2
    echo "        keybind rather than an absent package" >&2
    return 1
  fi

  # the xterm-kitty terminfo entry is NOT installed here — 4.3.1.terminfo
  # owns that claim across every machine, and a local box satisfies it for
  # free since the tarball ships the entry alongside the binary
  # .refs = gotcha.4-3-2-emulator.demo=terminfo-absence-cost, m1
}
