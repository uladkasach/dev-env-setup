#!/usr/bin/env bash
######################################################################
# .what = the kitty terminal itself — the pinned build, and its config
#
# .why it applies to EVERY machine, headless included, with NO early return
#   - a box HOLDS kitty without a display; only the window needs one
#   - a grove needs `kitten`, which every termwork skill drives
# .refs = gotcha.4-3-2-emulator.demo=kitty-loader-truth, m13
#
# usage:
#   rhx grove.provision --what 4.3.2.emulator --mode apply
######################################################################

# .what = print one ✋ failure (a headline plus optional detail lines), and count it
#   in the CALLER's `failed` (configure.verify), which bash scopes dynamically
_kitty_verify_fail() {
  printf '   ✋ %s\n' "$1" >&2
  shift
  local line
  for line in "$@"; do
    [[ -n "$line" ]] && printf '      %s\n' "$line" >&2
  done
  failed=$(( failed + 1 ))
}

grove_provision_4_3_2_emulator() {
  bundle.upgrade 4.3.2.emulator.provision.upsert
  bundle.upgrade 4.3.2.emulator.provision.verify
  bundle.upgrade 4.3.2.emulator.configure.upsert
  bundle.upgrade 4.3.2.emulator.configure.verify
}
