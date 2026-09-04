#!/usr/bin/env bash
######################################################################
# .what = prove cosmic-term is present AND at or above the keybind floor
#
# ⚠️ .why the version is part of the claim
#         an older cosmic-term runs fine and simply ignores `shortcuts_custom`.
#         so a presence-only check passes on the one box where this bundle's
#         `configure` phase silently does no work — the config lands, the file is
#         byte-correct, and ctrl+\ still does not open a window.
#
#         the version is what tells "configured" apart from "configured, and
#         read" (rule.require.upgrade-entries-verify-themselves).
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_3_1_term_provision_verify() {
  local floor="1.0.5"

  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no compositor on $GROVE_ENV_SERVER, so no"
    echo "      cosmic-term is expected here"
    return 0
  fi

  if ! command -v cosmic-term >/dev/null 2>&1; then
    echo "   ✋ cosmic-term is absent from PATH" >&2
    echo "      ⇒ COSMIC's Terminal action opens cosmic-term by default, so the" >&2
    echo "        desktop's own terminal keybind opens no window at all" >&2
    echo "      fix: rhx grove.provision --what 3.1.term --mode apply" >&2
    return 1
  fi

  # ⚠️ .why `timeout` wraps a mere `--version`
  #      cosmic-term is a GUI binary. even for `--version` it links a wayland
  #      client stack, and on a box whose compositor is wedged or whose
  #      WAYLAND_DISPLAY points at a dead socket that init blocks rather than
  #      errors. this runs on every `--mode plan`
  #      (`rule.require.bounded-probes-in-verifies`)
  local live
  live="$(timeout -k 5 10 cosmic-term --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"

  if [[ -n "$live" ]] && dpkg --compare-versions "$live" ge "$floor"; then
    echo "   • cosmic-term is $live, at or above the $floor floor ✔"
    return 0
  fi

  echo "   ✋ cosmic-term is ${live:-an unreadable version}, below the $floor floor" >&2
  echo "      ⇒ it reads no shortcuts_custom file at all below $floor, so this" >&2
  echo "        bundle's configure phase writes bytes no process loads — the" >&2
  echo "        config verifies as correct and the keybind still does not fire" >&2
  echo "      fix: rhx grove.provision --what 3.1.term --mode apply" >&2
  return 1
}
