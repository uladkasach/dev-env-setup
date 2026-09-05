#!/usr/bin/env bash
######################################################################
# .what = install the pinned usql static build into ~/.local/bin
# .ref  = https://github.com/xo/usql
#
# .the `_static` build
#   - the dynamic build links against unixodbc and a dozen client libraries
#   - the static one carries them, so no matched -dev set is owed
#   - ⇒ an apt upgrade cannot break it
#
# .a version pin
#   - usql's release assets are named per version
#   - a "latest" fetch needs a second api call to learn the filename
#   - ⇒ it also changes what one checkout installs between two runs
#
# guarantee:
#   - an extant binary at the pinned version short-circuits
#   - the binary is NEVER placed unless its archive matched its pinned digest
######################################################################

grove_provision_5_11_usql_provision_upsert() {
  ####################################################################
  # 🛑 the version moved 0.19.14 → 0.21.4, and that is a SECURITY fix
  #   - 0.19.14 is UNVERIFIABLE BY CONSTRUCTION on every route upstream offers
  #   - 📜 2026-08-13, against `repos/xo/usql/releases/tags/v0.19.14`:
  #       · no `checksums.txt` and no `.sha256` among its nine assets
  #       · no `.sig` or `.asc` beside any of them
  #       · github reports `no-digest` for every asset in that release
  #   - ⇒ the only pin expressible there is one COMPUTED from an unverified file
  #   - ⇒ that is a change detector that merely READS as an integrity check
  #   - ⚠️ the newest release answers differently on the third row:
  #
  #       v0.21.4  usql_static-0.21.4-linux-amd64.tar.bz2  sha256:93537a72…
  #
  #   - github digests assets stored since it began to, and 0.19.14 predates that
  #   - ⇒ so the fix is a new ROUTE, a release that CAN be checked, as `5.2.rust` did
  #   - (`gotcha.my-own-note-became-my-evidence`, `rule.require.verify-binary-downloads`)
  #
  # .where the pin came from, and what it does and does not buy
  #   - 📜 READ from `gh api -X GET repos/xo/usql/releases/latest`, 2026-08-13
  #   - the registry that serves the bytes also states the digest
  #   - ⇒ so it would not survive a compromise of github itself
  #   - it DOES catch a corrupt transfer, and a mirror that answers other bytes
  #   - it DOES catch a re-upload of this tag, because the value is in git
  ####################################################################
  # .the version comes from `_.sh`, which the verify reads too
  #   - ⇒ a bump cannot leave the two phases at odds
  local usql_version="$GROVE_USQL_VERSION"
  local usql_sha256="sha256:93537a7239737b3d0cd2f42b7a13766a455a40176be7c0896a3586cd698cf751"
  local usql_url="https://github.com/xo/usql/releases/download/v${usql_version}/usql_static-${usql_version}-linux-amd64.tar.bz2"
  local archive="usql_static-${usql_version}-linux-amd64.tar.bz2"
  local dst="$HOME/.local/bin/usql"

  ####################################################################
  # .short-circuit only when the extant binary IS the pin
  #   - ⇒ else a different version on disk makes the pin a comment, not a fact
  ####################################################################
  if [[ -x "$dst" ]] && "$dst" --version 2>/dev/null | grep -F "$usql_version" >/dev/null; then
    echo "   • usql $usql_version already installed; skipped"
    return 0
  fi

  # 🛑 a PRIVATE temp dir
  #   - a fixed `/tmp/usql-install` in a 1777 dir is claimable by any seat
  #   - ⇒ this phase then moves what it holds onto PATH as `usql`
  #   - see `src/grove.web.sh`
  local tmp_dir
  tmp_dir="$(web_tempdir usql)" || return 1

  if ! web_fetch "$usql_url" --into "$tmp_dir/$archive"; then
    echo "   ✋ could not install usql $usql_version from $usql_url" >&2
    echo "      ⇒ every database this repo talks to that is NOT postgres has no" >&2
    echo "        client on this box (psql covers postgres alone)" >&2
    echo "      ⇒ web_fetch named the wire fault above — a STALL wants a retry," >&2
    echo "        and a 404 here means the pinned release was withdrawn" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # ⚠️ verify BEFORE the extract
  #   - tar is handed the archive's own headers
  #   - ⇒ what it yields is made executable and put on PATH as `usql`
  if ! web_verify_sha256 --file "$tmp_dir/$archive" --sha256 "$usql_sha256"; then
    echo "      ⇒ usql is NOT installed, and the archive is discarded unopened." >&2
    echo "        a box with no usql beats a box that unpacked bytes nobody" >&2
    echo "        vouched for" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  echo "   • usql $usql_version verified against its pinned sha256 ✔"

  if ! tar -xjf "$tmp_dir/$archive" -C "$tmp_dir"; then
    echo "   ✋ could not extract $archive" >&2
    echo "      ⇒ it matched its pinned digest, so the bytes are correct — this" >&2
    echo "        is tar or bzip2 itself" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if [[ ! -f "$tmp_dir/usql_static" ]]; then
    echo "   ✋ the usql archive carried no 'usql_static' binary" >&2
    echo "      ⇒ it matched its pinned digest, so these ARE the bytes github" >&2
    echo "        stores — upstream changed the archive's layout, and the fix is" >&2
    echo "        to name the new path here, never to loosen the check" >&2
    echo "      read what it holds: tar -tjf $tmp_dir/$archive" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  mkdir -p "$HOME/.local/bin" || { rm -rf "$tmp_dir"; return 1; }

  if ! mv "$tmp_dir/usql_static" "$dst"; then
    echo "   ✋ could not install usql to $dst" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  chmod +x "$dst"
  rm -rf "$tmp_dir"

  echo "   • usql $usql_version installed → $dst"
}
