#!/usr/bin/env bash
######################################################################
# .what = make the pinned `starship` binary EXIST at ~/.local/bin/starship
#
# .why
#   - starship is the cross-shell prompt (ref: https://starship.rs/)
#   - the debian repos carry no version this repo would pin to
#   - ⇒ the release tarball is the source, pinned by version AND by sha256
#
# .why a sha256 pin
#   - an unverified fetch is a blocker under `rule.require.verify-binary-downloads`
#   - tls proves the host was reached, never that the BYTES are what upstream published
#   - starship publishes no gpg signature for its assets
#   - ⇒ a pinned sha256 is the strongest check available
#   - the hash below is github's server-computed asset digest
#   - a hash computed from a download here would only pin whatever bytes arrived
#   - to bump the version, change both lines in one edit:
#       gh api -X GET repos/starship/starship/releases/tags/vX.Y.Z \
#         --jq '.assets[] | .name + "  " + .digest'
#
# .why ~/.local/bin and not /usr/local/bin
#   - a prompt is the USER's, so it needs no sudo
#   - ⇒ a grove reached by a non-root account installs it with no privilege
#
# guarantee:
#   - idempotent: a box already at the pinned version does no work
#   - verified BEFORE extract, and a mismatch aborts and removes the temp dir
#   - ⇒ a bad download can never linger and get reused
######################################################################

# ⚠️ .why these three are named `starship_*` and not bare `version`/`sha256`/`url`
#   - `prove.sha256-pins-bite` re-proves every pinned download against upstream
#   - it finds a pin by the `<name>_version` / `<name>_sha256` / `<name>_url` convention
#   - ⇒ a bundle that names them bare is INVISIBLE to it
#   - invisible reads exactly like proven, since the play's page is green either way
#   - 📜 2026-08-13: this bundle and `4.1.fonts` both held a real pin and were both absent
#   - the pins were sound and the COVER was not (`gotcha.grepsafe-glob-goes-quiet`)
grove_provision_2_6_starship_provision_upsert() {
  local starship_version="1.24.2"
  local starship_sha256="00ff3c1f8ffb59b5c15d4b44c076bcca04d92cf0055c86b916248c14f3ae714a"
  local archive="starship-x86_64-unknown-linux-musl.tar.gz"
  local starship_url="https://github.com/starship/starship/releases/download/v${starship_version}/${archive}"
  local tmp_dir

  ####################################################################
  # already at the pin? then the declaration holds, and no work is done
  #
  # .why by explicit path and not the bare name
  #   - `~/.local/bin` reaches PATH via ubuntu's ~/.profile
  #   - ⇒ only if the dir existed when .profile was sourced
  #   - on a fresh box this phase is what creates it
  #   - a bare-name check passes on every re-run and fails on the first
  #   - ⇒ it holds wherever a human tests it by hand
  ####################################################################
  if [[ "$("$HOME/.local/bin/starship" --version 2>/dev/null | awk 'NR==1{print $2}')" == "$starship_version" ]]; then
    echo "   • starship v${starship_version} already installed — no work"
    return 0
  fi

  command -v curl &>/dev/null || pkg_install curl

  # .a PRIVATE temp dir
  #   - a fixed `/tmp/starship-install` in a 1777 dir is claimable by any seat
  #   - ⇒ this phase would extract and install whatever it holds
  #   - see `src/grove.web.sh`
  tmp_dir="$(web_tempdir starship)" || return 1

  if ! web_fetch "$starship_url" --into "$tmp_dir/$archive"; then
    echo "   ✋ the starship tarball did not download" >&2
    echo "      ⇒ web_fetch named the wire fault above — a STALL wants a retry," >&2
    echo "        a 404 means the pinned version moved. they differ" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # verify BEFORE extract — an unverified archive is never unpacked
  if ! web_verify_sha256 --file "$tmp_dir/$archive" --sha256 "$starship_sha256"; then
    echo "      ⇒ starship aborted; the tarball is discarded unextracted, so no" >&2
    echo "        binary reaches ~/.local/bin and no prompt is repointed at one" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • starship tarball sha256 verified"

  tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
  mkdir -p "$HOME/.local/bin"
  mv "$tmp_dir/starship" "$HOME/.local/bin/starship"
  chmod +x "$HOME/.local/bin/starship"
  rm -rf "$tmp_dir"

  echo "   • starship v${starship_version} installed to ~/.local/bin/starship"
}
