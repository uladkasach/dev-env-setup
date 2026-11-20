#!/usr/bin/env bash
######################################################################
# .what = prove the crew gate reads a known purpose from this seat's marker
#
# .it reads the marker the gate's way — first line, whitespace cut — so a verdict
#   here is the verdict a sprout meets
#
# guarantee:
#   - READ-ONLY
#
# exit:
#   0 = the marker reads the declared word, or another word the gate knows
#   1 = absent, or a word the gate reads as no purpose; the fix is named
######################################################################

grove_provision_5_25_purpose_configure_verify() {
  grove_provision_5_25_purpose_declines && return 0

  local path want have
  path="$(grove_provision_5_25_purpose_path)"
  want="$(grove_provision_5_25_purpose_declared)"
  have="$(grove_provision_5_25_purpose_read)"

  if [[ "$have" == "$want" ]]; then
    echo "   • the crew gate reads purpose '$have' from $path ✔"
    return 0
  fi
  if [[ "$have" == "lab" || "$have" == "work" ]]; then
    echo "   • the crew gate reads purpose '$have' from $path ✔ (a stated purpose, kept over '$want')"
    return 0
  fi

  if [[ -z "$have" ]]; then
    echo "   ✋ $path is absent, so the crew gate finds no purpose and fails closed" >&2
  else
    echo "   ✋ $path reads '$have', which the crew gate knows as no purpose (work|lab)" >&2
  fi
  echo "      ⇒ every queued sprout refuses this box until it reads '$want'" >&2
  echo "      fix: rhx grove.provision --what 5.25.purpose --mode apply" >&2
  return 1
}
