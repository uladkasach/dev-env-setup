#!/usr/bin/env bash
######################################################################
# .what = declare cosmic-term's custom keybinds — ctrl+\ opens a new window
#
# .ctrl+\ specifically
#   - it is the same new-window keybind `4.3.kitty` declares
#   - so the gesture is one muscle memory across both terminals
#
# guarantee
#   - idempotent: the file is DECLARED, so a re-run rewrites identical bytes
#   - it DECLINES where no compositor exists
######################################################################

grove_provision_3_1_term_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no cosmic-term on $GROVE_ENV_SERVER to configure"
    return 0
  fi

  local dir="$HOME/.config/cosmic/com.system76.CosmicTerm/v1"
  mkdir -p "$dir" || return 1

  cat > "$dir/shortcuts_custom" <<'SHORTCUTS'
{
    (
        modifiers: [
            Ctrl,
        ],
        key: "\\",
    ): WindowNew,
}
SHORTCUTS

  echo "   • cosmic-term keybinds declared → $dir/shortcuts_custom"
}
