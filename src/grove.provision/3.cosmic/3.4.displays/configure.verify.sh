#!/usr/bin/env bash
######################################################################
# .what = prove each connected declared monitor is at its declared scale,
#         at its native mode, and is the sole enabled output
#
# .a declared monitor that is NOT connected is 🌙, never ✔
#   - its scale cannot be read without it, so a ✔ would claim a fact
#     this run never observed (rule.forbid.failhide)
######################################################################

grove_provision_3_4_displays_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@unix ]]; then
    echo "   🌙 declined — $GROVE_ENV_SERVER has no screen a human reads"
    return 0
  fi
  if ! grove_provision_3_4_displays_reachable; then
    echo "   🌙 declined — no cosmic session this shell can reach, so no output can be read"
    return 0
  fi

  local declared connected fail=0 found=0
  declared="$(grove_provision_3_4_displays_declared)"
  connected="$(grove_provision_3_4_displays_connected)"

  local dmk dmd dsc want c mk md sc sz hz hit native
  while IFS='|' read -r dmk dmd dsc; do
    [[ -n "$dmd" ]] || continue
    want="$(grove_provision_3_4_displays_pct "$dsc")"
    hit=no
    while IFS='|' read -r c mk md sc sz hz; do
      [[ "$mk" == "$dmk" && "$md" == "$dmd" ]] || continue
      hit=yes; found=1
      native="$(timeout 10 cosmic-randr list 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' |
        awk -v o="$c" '/^[^ ]/ { on = ($1 == o) } on && /\(preferred\)/ { print $1; exit }')"
      if [[ "$sc" == "$want" && ( -z "$native" || "$sz" == "$native" ) ]]; then
        echo "   • $dmd ($c) is $sz at $sc ✔"
      else
        echo "   ✋ $dmd ($c) is ${sz:-?} at ${sc:-?}, declared ${native:-native} at $want" >&2
        echo "      fix: rhx grove.provision --what 3.4.displays --mode apply" >&2
        fail=1
      fi
    done <<<"$connected"
    [[ "$hit" == yes ]] || echo "   🌙 $dmd is not connected — its scale is unobserved this run"
  done <<<"$declared"

  # the sole-screen claim holds only where a declared monitor is attached
  if [[ "$found" == 1 ]]; then
    local others
    others="$(timeout 10 cosmic-randr list 2>/dev/null | sed -E 's/\x1b\[[0-9;]*m//g' |
      awk '/^[^ ]/ && /\(enabled\)/ { print $1 }')"
    local o ok
    for o in $others; do
      ok=no
      while IFS='|' read -r c mk md _; do
        [[ "$c" == "$o" ]] || continue
        while IFS='|' read -r dmk dmd _; do [[ "$mk" == "$dmk" && "$md" == "$dmd" ]] && ok=yes; done <<<"$declared"
      done <<<"$connected"
      if [[ "$ok" != yes ]]; then
        echo "   ✋ $o is enabled beside the declared monitor — the standard layout is that monitor alone" >&2
        echo "      fix: rhx grove.provision --what 3.4.displays --mode apply" >&2
        fail=1
      fi
    done
    [[ "$fail" == 0 ]] && echo "   • the declared monitor is the sole enabled screen ✔"
  fi

  return "$fail"
}
