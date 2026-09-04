#!/usr/bin/env bash
######################################################################
# .what = put cosmic-term on this box at 1.0.5 or newer
#
# .a version FLOOR, not a pin
#   - `5.11.usql` pins exactly, because two boxes must behave alike on a database
#   - here the demand is only "new enough to read a shortcuts file"
#   - an exact pin would fight apt on every release
#
# guarantee
#   - idempotent: a version at or above the floor short-circuits
#   - it DECLINES where no compositor exists
######################################################################

grove_provision_3_1_term_provision_upsert() {
  local floor="1.0.5"

  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — cosmic-term draws through wayland, and"
    echo "      $GROVE_ENV_SERVER runs no compositor to draw into"
    return 0
  fi

  local live
  live="$(cosmic-term --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"

  if [[ -n "$live" ]] && dpkg --compare-versions "$live" ge "$floor"; then
    echo "   • cosmic-term $live already meets the $floor floor; skipped"
    return 0
  fi

  pkg_refresh || true
  pkg_install cosmic-term || return 1

  echo "   • cosmic-term installed ($(cosmic-term --version 2>/dev/null | head -1))"
}
