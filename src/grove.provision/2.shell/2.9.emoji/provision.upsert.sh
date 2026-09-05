#!/usr/bin/env bash
######################################################################
# .what = make the emoji lookup index EXIST at ~/.local/share/emoji/emoji.tsv
#
# .the two sources
#   - CLDR annotations = the KEYWORDS, so 'happy' finds 😀
#   - unicode's own names cannot do that
#   - kitty's picker indexes unicode NAMES alone, so 'happy' finds no smile there
#   - emoji-test.txt = the DEFINITION of what IS an emoji
#   - CLDR annotates *characters*, ':' and 5 invisible skin-tone modifiers among them
#   - ⇒ the intersect is what stops ':colon<TAB>'
#   - without it that gesture inserts the trigger char you just typed
#
# 🛑 both are pinned to a VERSION, never to `main` or `latest`
#   - each of those is a ref that MOVES
#   - 📜 2026-08-14: `emoji/latest/emoji-test.txt` serves bytes stamped `# Version: 17.0`
#   - `emoji/17.0/emoji-test.txt` answers 404
#   - ⇒ the bytes `latest` serves CANNOT BE PINNED AT ALL
#   - unicode has not published that version's own directory
#   - a ref that moves can carry no hash
#   - ⇒ such a fetch satisfies neither `rule.require.verify-binary-downloads`
#     nor `prove.every-fetch-is-verified`
#   - 16.0 is the newest version with a stable versioned path
#
# ⚠️ the two pins are TIER 2, and the bundle says so
#   - neither vendor publishes a checksum beside these files
#   - ⇒ each hash below was computed from a download
#   - that pins WHICH BYTES WE SAW, never that upstream vouches for them
#   - it is weaker than the github server-side digests the release bundles use
#   - `prove.sha256-pins-bite` carries the distinction per pin (`term=pin`)
#   - ⇒ it is sufficient here because both are DATA
#   - the transform that distills them verifies its own output
#   - the result is read by a widget that inserts characters into a command line
#   - no byte of either file is executed
#
# .why a stamp file beside the index
#   - the index is derived from exactly these two pins
#   - ⇒ a re-run whose pins match the stamp has no work to do
#   - it must not re-fetch ~1 MB on every apply
#   - (`rule.require.idempotent-install-procedures`)
#   - bump either pin and the stamp disagrees, so the next apply rebuilds
#
# guarantee:
#   - idempotent: a box already at both pins reaches the wire ZERO times
#   - both artifacts are verified BEFORE the transform reads them
#   - the transform self-checks its output
#   - ⇒ a bad index is never moved into place (`rule.forbid.failhide`)
######################################################################

grove_provision_2_9_emoji_provision_upsert() {
  ####################################################################
  # ⚠️ .why the `<name>_version` / `<name>_sha256` / `<name>_url` triple
  #   - `prove.sha256-pins-bite` finds every pinned download by that convention
  #   - ⇒ a bundle that names them bare is INVISIBLE to it
  #   - invisible reads exactly like proven, since the play's page is green either way
  #
  # ⚠️ this bundle carries TWO pins in one upsert
  #   - a reader that took `head -1` per bundle would leave the SECOND pin uncovered
  #   - ⇒ that play iterates PINS rather than bundles
  ####################################################################
  local emojicldr_version="48.2.1"
  local emojicldr_sha256="f22083cb86dffb63a643d5bacb5d9899f82d2fa5d388ad4f3aed72184acef505"
  local emojicldr_url="https://raw.githubusercontent.com/unicode-org/cldr-json/${emojicldr_version}/cldr-json/cldr-annotations-full/annotations/en/annotations.json"

  local emojilist_version="16.0"
  local emojilist_sha256="24f0c534e86cf142e2496953e8f0e46a3e702392911eddcd29c6cced85139697"
  local emojilist_url="https://unicode.org/Public/emoji/${emojilist_version}/emoji-test.txt"

  local index stamp want tmp_dir
  index="$(grove_provision_2_9_emoji_index_path)"
  stamp="$(grove_provision_2_9_emoji_stamp_path)"
  want="cldr=${emojicldr_sha256} list=${emojilist_sha256}"

  ####################################################################
  # already at both pins? then the declaration holds; do no work
  #
  # ⚠️ the index MUST be tested too, not the stamp alone
  #   - a stamp with no index beside it is what a run cut partway leaves
  #   - ⇒ a check on the stamp alone reports converged over an absent index
  #   - the widget then reports a fault at every shell start
  #   - and no run is left to fix it
  ####################################################################
  if [[ -s "$index" && -f "$stamp" && "$(cat "$stamp" 2>/dev/null)" == "$want" ]]; then
    echo "   • emoji index already built from these pins ($(wc -l < "$index") emoji) ✔"
    return 0
  fi

  ####################################################################
  # jq is a dependency of THIS bundle, so this bundle installs it
  #
  # 🛑 an ASSERT with a `--what 2.1.toolkit` pointer is the forbidden shape
  #   - (`rule.require.bundles-own-their-dependencies`)
  #   - the two arguments for one are both wrong:
  #   - "a second `pkg_install` would be a second declaration"
  #   - ⇒ two bundles that install one tool is one true dependency, checkable at each
  #   - the tree already does this — `flatpak` is installed by `1.3.1.firefox` and `6.1.flatpaks`
  #   - "on a seat with no root it would fail over a package already present"
  #   - ⇒ 📜 2026-08-14: measured false
  #   - `pkg_install` reads `pkg_present` FIRST and returns 0 before `pkg_assert_sudo`
  #   - (`grove.pkg.sh:386-403`)
  #   - ⇒ on a camper with jq present this costs one dpkg read and no sudo
  #
  # ⚠️ a decline whose REASON is wrong is the hardest kind to catch
  #   - the verdict looks careful, so a reader agrees and moves on
  #   - (`term=decline._.choice.reason.md`)
  #   - ⇒ the bar an assert fails is this repo's test: can `--what 2.9.emoji`
  #     alone converge on a fresh box?
  ####################################################################
  if ! command -v jq >/dev/null 2>&1; then
    pkg_install jq || return 1
    echo "   • jq installed — this box shipped without it"
  fi

  tmp_dir="$(web_tempdir emoji)" || return 1

  if ! web_fetch "$emojicldr_url" --into "$tmp_dir/annotations.json" --within 300; then
    echo "   ✋ the cldr annotations did not download" >&2
    echo "      ⇒ web_fetch named the wire fault above — a STALL wants a retry," >&2
    echo "        a 404 means tag ${emojicldr_version} moved or was yanked" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! web_verify_sha256 --file "$tmp_dir/annotations.json" --sha256 "$emojicldr_sha256"; then
    echo "      ⇒ emoji aborted; no index is written, so the widget keeps the" >&2
    echo "        index it already had rather than read unverified keywords" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! web_fetch "$emojilist_url" --into "$tmp_dir/emoji-test.txt" --within 300; then
    echo "   ✋ the unicode emoji list did not download" >&2
    echo "      ⇒ a 404 here means unicode moved version ${emojilist_version}" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  if ! web_verify_sha256 --file "$tmp_dir/emoji-test.txt" --sha256 "$emojilist_sha256"; then
    echo "      ⇒ emoji aborted; no index is written" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  echo "   • both emoji sources verified (cldr ${emojicldr_version}, unicode ${emojilist_version})"

  ####################################################################
  # the transform reaches no network — it is handed both files
  #   - ⇒ a failure below is a DATA fault, never a wire one
  #   - its message must not send a reader to check a network that is fine
  ####################################################################
  if ! bash "$GROVE_SRC/grove.provision/2.shell/2.9.emoji/emoji.index.build.sh" \
        --cldr "$tmp_dir/annotations.json" \
        --list "$tmp_dir/emoji-test.txt" \
        --into "$index"; then
    echo "   ✋ the emoji index failed to build from two VERIFIED inputs" >&2
    echo "      ⇒ the bytes are the pinned bytes, so this is the transform or" >&2
    echo "        the upstream SHAPE, never the wire. read the canary that" >&2
    echo "        failed above — each names the filter step it guards" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  rm -rf "$tmp_dir"

  # the stamp is written LAST
  #   - ⇒ it can never claim an index the transform did not finish
  printf '%s' "$want" > "$stamp"

  echo "   • emoji index built ($(wc -l < "$index") emoji)"
}
