#!/usr/bin/env bash
# .what = put FiraCode and Hack Nerd Font Mono on this box
# .why two fonts, not one — FiraCode ships the code ligatures (→, !=, =>),
#   Hack Nerd Font ships the icon range nvim's tree and statusline draw
#   from, and neither is a superset of the other
# .why the "Mono" variant of Hack, specifically — only `Mono` keeps every
#   glyph, icons included, at ONE cell wide; the other two draw icons at
#   double width, which shifts every column after
#
# guarantee
#   - idempotent: an extant Hack*.ttf short-circuits the download
#   - it DECLINES where no screen exists

grove_provision_4_1_fonts_provision_upsert() {
  # a font is rasterized by the window that draws it — on a grove that
  # window is the LOCAL kitty; this bundle's `_.sh` covers the terminfo mirror
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no process here"
    echo "      would ever open a font file (the local window draws the glyphs)"
    return 0
  fi

  # 1. FiraCode — through the package boundary, never a bare `apt install`,
  # which is a second way to ask for a package
  pkg_install fonts-firacode || return 1

  # 1b. fontconfig — the index this phase writes to and the verify reads
  # from. declared HERE, not in `2.1.toolkit`, since exactly one bundle
  # calls it; it cannot ride on `fonts-firacode`, which reaches it by dpkg
  # TRIGGER (no Depends), so on a minimal box the font lands and no index does
  pkg_install fontconfig || return 1

  # 2. Hack Nerd Font Mono — a github release, not a debian package; debian
  # ships no nerd-font patch of Hack
  local font_dir="$HOME/.local/share/fonts"
  if compgen -G "$font_dir/Hack*.ttf" >/dev/null 2>&1; then
    echo "   • Hack Nerd Font already present; skipped"
    return 0
  fi

  mkdir -p "$font_dir" || {
    echo "   ✋ could not create $font_dir" >&2
    return 1
  }

  # a PRIVATE temp dir — a fixed `/tmp/Hack-NerdFont.zip` sits in a 1777
  # dir any seat can claim first; `web_tempdir` returns a 0700 dir instead
  local tmp_dir
  tmp_dir="$(web_tempdir fonts)" || return 1
  local tmp_zip="$tmp_dir/Hack-NerdFont.zip"

  # the pin — a VERSION and its hash, and neither is optional. this url is
  # NOT `/latest/download/`, which names whatever released most recently,
  # so two applies a month apart would install different glyph sets and no
  # hash would be possible; the hash comes from github, computed server-side
  # (rule.require.verify-binary-downloads):
  #   gh api -X GET repos/ryanoasis/nerd-fonts/releases/tags/v3.5.0 \
  #     --jq '.assets[] | select(.name=="Hack.zip") | .digest'
  # named `fonts_*`, and the url a VARIABLE — `prove.sha256-pins-bite` finds
  # a pin by `<name>_version`/`_sha256`/`_url`, and a bare name or an inline
  # url is INVISIBLE to it (gotcha.grepsafe-glob-goes-quiet)
  local fonts_version="v3.5.0"
  local fonts_sha256="24a54aa41ff8ca5829409bfeb1bc2883b9fcafbf79f8d4b7674898550cb5e3b3"
  local fonts_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${fonts_version}/Hack.zip"

  if ! web_fetch "$fonts_url" --into "$tmp_zip"; then
    echo "   ✋ could not download Hack.zip from nerd-fonts $fonts_version" >&2
    echo "      ⇒ absent the font, nvim's tree and statusline draw tofu (▯) where" >&2
    echo "        an icon belongs — a defect that reads as a plugin bug" >&2
    echo "      ⇒ web_fetch named the wire fault above. this url names a PINNED" >&2
    echo "        release, so a 404 means that tag or asset was withdrawn" >&2
    echo "        upstream — read the release page before you bump the pin" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # verify BEFORE unzip — `unzip -oq … -d "$font_dir"` writes into $HOME
  # with `-o`, no prompt, so an unverified archive would replace files there unasked
  if ! web_verify_sha256 --file "$tmp_zip" --sha256 "$fonts_sha256"; then
    echo "      ⇒ the archive is discarded unopened; no glyph reached \$HOME" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! unzip -oq "$tmp_zip" -d "$font_dir"; then
    echo "   ✋ could not extract $tmp_zip into $font_dir" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"

  # fontconfig caches by directory mtime, so a new file is invisible until a re-scan
  fc-cache -f "$font_dir" >/dev/null 2>&1

  echo "   • Hack Nerd Font installed → $font_dir"
}
