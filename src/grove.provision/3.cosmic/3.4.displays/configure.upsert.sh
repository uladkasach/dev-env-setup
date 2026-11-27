#!/usr/bin/env bash
######################################################################
# .what = put each connected declared monitor at its declared mode + scale,
#         and make it the SOLE enabled output
#
# .the standard layout, when a declared monitor is attached
#   - it is the only screen in use: native mode, declared scale
#   - every other output — the laptop panel, if its lid is open — is off
#   - with no declared monitor attached, no output is touched
#
# 🛑 .an output is disabled only AFTER a declared one is confirmed enabled
#   - to disable first, then fail the declared monitor's mode set, leaves a
#     box with no lit screen and a human with no way to see the error
#
# guarantee
#   - idempotent: an output already at its declared state is left alone
#   - it DECLINES where no reachable compositor exists (cloud, cicd, ssh)
######################################################################

grove_provision_3_4_displays_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@unix ]]; then
    echo "   🌙 declined — monitor layout is a fact of a desk, and"
    echo "      $GROVE_ENV_SERVER has no screen a human reads"
    return 0
  fi
  if ! grove_provision_3_4_displays_reachable; then
    echo "   🌙 declined — no cosmic session this shell can reach"
    echo "      ⇒ run it from a terminal inside the desktop session"
    return 0
  fi

  local declared connected
  declared="$(grove_provision_3_4_displays_declared)"
  connected="$(grove_provision_3_4_displays_connected)"

  ####################################################################
  # 1. each connected declared monitor → native mode + declared scale
  ####################################################################
  local -a sole=()
  local c mk md sc sz hz dmk dmd dsc want
  while IFS='|' read -r c mk md sc sz hz; do
    [[ -n "$c" ]] || continue
    while IFS='|' read -r dmk dmd dsc; do
      [[ "$mk" == "$dmk" && "$md" == "$dmd" ]] || continue
      want="$(grove_provision_3_4_displays_pct "$dsc")"

      # the native mode is the one cosmic-randr marks preferred
      local native
      native="$(timeout 10 cosmic-randr list 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' |
        awk -v o="$c" '/^[^ ]/ { on = ($1 == o) } on && /\(preferred\)/ { print $1, $3; exit }')"
      local nsz="${native%% *}" nhz="${native##* }"
      [[ -n "$nsz" ]] || { nsz="$sz"; nhz="$hz"; }

      if [[ "$sc" == "$want" && "$sz" == "$nsz" ]]; then
        echo "   • $md ($c) already $sz at $sc"
      else
        timeout 15 cosmic-randr mode --scale "$dsc" --refresh "$nhz" "$c" "${nsz%x*}" "${nsz#*x}" || {
          echo "   ✋ $md ($c): cosmic-randr refused $nsz at $want" >&2
          return 1
        }
        echo "   • $md ($c) set to $nsz at $want (was ${sz:-?} at ${sc:-?})"
      fi
      sole+=("$c")
    done <<<"$declared"
  done <<<"$connected"

  if [[ ${#sole[@]} -eq 0 ]]; then
    echo "   🌙 no declared monitor is connected — the layout is left as is"
    return 0
  fi

  ####################################################################
  # 2. every other output → off, now that a declared one is confirmed lit
  ####################################################################
  local -a enabled=()
  mapfile -t enabled < <(timeout 10 cosmic-randr list 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' |
    awk '/^[^ ]/ && /\(enabled\)/ { print $1 }')
  local lit=no o s
  for o in "${enabled[@]}"; do for s in "${sole[@]}"; do [[ "$o" == "$s" ]] && lit=yes; done; done
  if [[ "$lit" != yes ]]; then
    echo "   ✋ no declared monitor reads enabled after its mode set — no other output is touched" >&2
    return 1
  fi

  local keep
  for o in "${enabled[@]}"; do
    keep=no
    for s in "${sole[@]}"; do [[ "$o" == "$s" ]] && keep=yes; done
    [[ "$keep" == yes ]] && continue
    timeout 15 cosmic-randr disable "$o" || { echo "   ✋ could not disable $o" >&2; return 1; }
    echo "   • $o disabled — the declared monitor is the sole screen"
  done
  return 0
}
