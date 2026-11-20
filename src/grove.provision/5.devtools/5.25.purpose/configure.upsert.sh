#!/usr/bin/env bash
######################################################################
# .what = findsert `~/.grove/purpose` on the camp seat, from the platform's purpose
#
# guarantee:
#   - idempotent: a marker that already reads the declared word is a no-op
#   - a marker that holds ANOTHER word is kept, never overwritten (see `_.sh`)
#   - one atomic swap: the gate never reads a half-written file
#   - no root: the marker sits in this seat's own home
######################################################################

grove_provision_5_25_purpose_configure_upsert() {
  grove_provision_5_25_purpose_declines && return 0

  local path want have
  path="$(grove_provision_5_25_purpose_path)"
  want="$(grove_provision_5_25_purpose_declared)"
  have="$(grove_provision_5_25_purpose_read)"

  # already declared — the same word is a no-op, another word is a stated purpose
  if [[ "$have" == "$want" ]]; then
    echo "   • purpose already '$want' at $path — no work"
    return 0
  fi
  if [[ -n "$have" ]]; then
    echo "   🌙 $path already reads '$have' — kept; a stated purpose outranks the"
    echo "      platform's '$want'. to change it: echo $want | tee $path"
    return 0
  fi

  # write it whole, then swap, so the gate reads the old file or the new one
  if ! mkdir -p "$(dirname "$path")"; then
    echo "   ✋ could not create $(dirname "$path")" >&2
    echo "      read why: the mkdir error above — usually a permission or a full disk" >&2
    return 1
  fi
  local tmp
  if ! tmp="$(mktemp "$path.XXXXXX")"; then
    echo "   ✋ could not stage a temp file beside $path" >&2
    return 1
  fi
  if ! { printf '%s\n' "$want" > "$tmp" && mv -f "$tmp" "$path"; }; then
    rm -f "$tmp"
    echo "   ✋ could not write $path" >&2
    echo "      ⇒ the crew gate finds no marker and fails closed: no crew boots here" >&2
    echo "      read why: the error above — usually a permission or a full disk" >&2
    return 1
  fi
  echo "   • purpose declared '$want' → $path"
}
