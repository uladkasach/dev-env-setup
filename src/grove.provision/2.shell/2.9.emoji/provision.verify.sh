#!/usr/bin/env bash
######################################################################
# .what = prove the emoji index EXISTS and is SOUND
#
# .why it re-runs the transform's own canaries rather than count lines
#   - a line count proves the file is big
#   - it is silent about whether ':' survived the filter
#   - it is silent about whether ❤️ and ⚠️ made it through the FE0F strip
#   - 📜 both of those are defects this transform has shipped
#   - ⇒ the check is the same `--check` the build runs on itself
#   - declared ONCE in `src/emoji.index.build.sh`
#   - (`rule.require.identical-bundle-composition`)
#
# ⚠️ it also tests the STAMP against the checkout
#   - the index can be sound and STALE, built from an older pin pair
#   - ⇒ a check on soundness alone reports ✔ on a box the checkout would rebuild
#   - the plan a human reads then omits the one change a re-apply makes
#   - (`rule.require.judge-declared-state-not-live-state`)
#
# guarantee:
#   - it reaches no network; every read is local
#   - bounded: a handful of awk passes over one flat file
######################################################################

grove_provision_2_9_emoji_provision_verify() {
  local index stamp upsert declared held
  index="$(grove_provision_2_9_emoji_index_path)"
  stamp="$(grove_provision_2_9_emoji_stamp_path)"
  upsert="$GROVE_SRC/grove.provision/2.shell/2.9.emoji/provision.upsert.sh"

  if [[ ! -s "$index" ]]; then
    echo "   ✋ no emoji index at $index" >&2
    echo "      ⇒ the widget states this at every shell start, so it is loud" >&2
    echo "        already — but it is loud at the HUMAN, and this is the run" >&2
    echo "        that can fix it" >&2
    echo "      fix: grove.provision --what 2.9.emoji --mode apply" >&2
    return 1
  fi

  ####################################################################
  # the SOUNDNESS half — the transform's own canaries, re-run here
  ####################################################################
  local emoji_build="$GROVE_SRC/grove.provision/2.shell/2.9.emoji/emoji.index.build.sh"
  if ! bash "$emoji_build" --check "$index" >/dev/null 2>&1; then
    echo "   ✋ the emoji index is present and UNSOUND" >&2
    echo "      ⇒ read the canary that failed:" >&2
    echo "        bash $emoji_build --check $index" >&2
    echo "      fix: grove.provision --what 2.9.emoji --mode apply" >&2
    return 1
  fi

  ####################################################################
  # the CURRENCY half — was it built from the pins this checkout declares?
  #
  # ⚠️ the declared pair is read out of the UPSERT
  #   - ⇒ a version bump there carries here with no edit
  #   - a copy of the two hashes here would be a second declaration
  #   - it goes stale in the one direction that matters
  #   - ⇒ this verify keeps its ✔ against a pin the tree no longer installs
  ####################################################################
  declared="cldr=$(grep -oE 'emojicldr_sha256="[^"]+"' "$upsert" | head -1 | cut -d'"' -f2)"
  declared="$declared list=$(grep -oE 'emojilist_sha256="[^"]+"' "$upsert" | head -1 | cut -d'"' -f2)"

  if [[ "$declared" == "cldr= list=" ]]; then
    echo "   ✋ this verify could not read the declared pins out of the upsert" >&2
    echo "      ⇒ that is THIS PHASE's gap, and NOT a fact about the index. do" >&2
    echo "        not rebuild — teach this reader the shape the upsert now uses" >&2
    return 1
  fi

  held="$(cat "$stamp" 2>/dev/null || true)"
  if [[ "$held" != "$declared" ]]; then
    echo "   ✋ the emoji index is sound but STALE — it was built from other pins" >&2
    echo "      held:     ${held:-<no stamp>}" >&2
    echo "      declared: $declared" >&2
    echo "      fix: grove.provision --what 2.9.emoji --mode apply" >&2
    return 1
  fi

  echo "   • emoji index sound and current ($(wc -l < "$index") emoji) ✔"
}
