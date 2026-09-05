#!/usr/bin/env bash
######################################################################
# .what = prove cosmic-term's keybind file is declared and holds the action
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_3_1_term_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no cosmic-term on $GROVE_ENV_SERVER to configure"
    return 0
  fi

  local file="$HOME/.config/cosmic/com.system76.CosmicTerm/v1/shortcuts_custom"

  if [[ ! -r "$file" ]]; then
    echo "   ✋ no cosmic-term keybind file at $file" >&2
    echo "      ⇒ ctrl+\\ opens no window in cosmic-term, so the gesture that" >&2
    echo "        works in kitty silently does not here" >&2
    echo "      fix: rhx grove.provision --what 3.1.term --mode apply" >&2
    return 1
  fi

  if grep -F 'WindowNew' "$file" >/dev/null; then
    echo "   • cosmic-term's ctrl+\\ new-window keybind is declared ✔"
    return 0
  fi

  echo "   ✋ $file exists but declares no WindowNew action" >&2
  echo "      ⇒ the file is here, so a presence check would pass while the" >&2
  echo "        keybind it exists for is absent" >&2
  echo "      fix: rhx grove.provision --what 3.1.term --mode apply" >&2
  return 1
}
