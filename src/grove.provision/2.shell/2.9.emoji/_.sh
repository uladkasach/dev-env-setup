#!/usr/bin/env bash
# .what = inline emoji autocomplete for zsh
#   ':turt<TAB>' -> 🐢   ':zap:' -> ⚡   ':zap<Enter>' -> emoji zap
# .why the two halves are two PHASES — PROVISION builds the index at
#   `~/.local/share/emoji/emoji.tsv` and reaches the wire; CONFIGURE installs
#   the widget at `~/.zshrc.emoji.sh` and reaches no network; each fails for
#   a different reason and needs a different fix
# .why it declines on a box with no human — every gesture is a KEYSTROKE
#   (TAB, ':', Enter) read by zle, and an agent presses none of them, so a
#   grove would fetch ~1 MB to serve a widget nobody can trigger
#   (define.6-apps-is-laptop-only)
# .why the decline does not hide the fetch from every check — a path that
#   runs on one box class, once, is the DARKEST corner
#   (define.provision-defect-shapes); `prove.sha256-pins-bite` discovers
#   both pins from the tree and runs on a grove instead
# .why 2.9 runs last — it needs 2.5.zsh's `.zshrc` and 2.1.toolkit's
#   `jq`/`fzf`, the one child that needs another child's ARTIFACT
#
# usage:
#   grove.provision --what 2.9.emoji --mode apply     # install / rebuild
#   grove.provision --what 2.9.emoji --mode plan      # is it current?

grove_provision_2_9_emoji() {
  # the gate sits on the SECTION's behalf, at the bundle that declines, never
  # as a case in the parent (rule.require.identical-bundle-composition). the
  # pad is COMPUTED, since this decline prints from dispatch, not a phase
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    local pad
    pad="$(printf '%*s' $(( (BUNDLE_DEPTH + 1) * 3 )) '')"
    echo "   ${pad}🌙 declined — every gesture is a keystroke (TAB, ':', Enter)"
    echo "   ${pad}   read by zle, and $GROVE_ENV_SERVER has no human to press one"
    return 0
  fi

  bundle.upgrade 2.9.emoji.provision.upsert
  bundle.upgrade 2.9.emoji.provision.verify
  bundle.upgrade 2.9.emoji.configure.upsert
  bundle.upgrade 2.9.emoji.configure.verify
}

# .what = operations shared by this bundle's phases
# .why declared ONCE here rather than per phase — the index path is read by
#   three of the four phases, and a copy in each is three declarations of
#   one fact (the shape `5.11.usql`'s two phases once drifted on)
grove_provision_2_9_emoji_index_path() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/emoji/emoji.tsv"
}

grove_provision_2_9_emoji_stamp_path() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/emoji/emoji.pins"
}
