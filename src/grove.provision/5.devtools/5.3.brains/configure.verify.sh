#!/usr/bin/env bash
######################################################################
# .what = prove each declared key is LIVE — in BOTH files the upsert writes
#
# .it reads each key back with jq, and never greps the file
#   - the write is a deep MERGE
#   - ⇒ a key can be present in the file and still hold the wrong value
#   - a human's own edit does that, as does an older patch
#   - a grep for the key NAME would report ✔ on either
#   - ⇒ `jq` reads the VALUE, the only fact that changes what claude does
#
# 🛑 .it finds the GLOBAL CONFIG through the cli's OWN two-branch lookup
#   - that lookup takes two branches, and a verify that hardcoded one would
#     report `absent` forever on a box that sat on the other — a false ✋, which
#     decays into a silenced check (`gotcha.a-check-that-cries-wolf`)
#   - ⇒ ONE reader, declared in this bundle's `_.sh`, asked by both halves,
#     so the upsert and the verify cannot read the same box two ways (`define.cry-wolf-measurements`, m.9)
#
# ⚠️ .each claim reads the file at its own moment: a write between two claims makes each true of
#   the instant it read, as a write a second after the plan would. the plan is a survey, and the
#   next one re-reads; the converge, which acts on what it reads, reads ONE backup copy
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state (clamp arm 17h: a hooked, writable home with
#     every claim off is left byte-equal, all three files at their modes)
######################################################################

####################################################################
# .what = the readers this verify asks — declared once, in this bundle's `_.sh`
# .why  = the entrypoint sources `_.sh` with every phase, so they are present on every run. a
#         verify sourced ALONE (a play, a probe) sources that `_.sh` rather than guess a path or
#         skip a claim. absent even so, the verify refuses whole, never a claim at a time
# .note = every reader is named, so a `_.sh` that failed partway cannot pass on the one name it
#         defined first; a missed reader would surface as `command not found`, misnamed as a jq read
####################################################################
_grove_provision_5_3_brains_verify_readers_present() {
  declare -F \
    _grove_provision_5_3_brains_settings_path \
    _grove_provision_5_3_brains_arrow_target \
    _grove_provision_5_3_brains_file_mode \
    _grove_provision_5_3_brains_lock_declared \
    _grove_provision_5_3_brains_mode_declared \
    _grove_provision_5_3_brains_lock_of_mode \
    _grove_provision_5_3_brains_role_hooks_by_author \
    _grove_provision_5_3_brains_unjudged_hooks_by_author \
    _grove_provision_5_3_brains_census_total \
    _grove_provision_5_3_brains_census_tree \
    _grove_provision_5_3_brains_config_path \
    _grove_provision_5_3_brains_config_diff_panel \
    _grove_provision_5_3_brains_keybindings_chord >/dev/null 2>&1
}

if ! _grove_provision_5_3_brains_verify_readers_present; then
  _GROVE_PROVISION_5_3_BRAINS_SHARED="$(dirname "${BASH_SOURCE[0]}")/_.sh"
  [[ -r "$_GROVE_PROVISION_5_3_BRAINS_SHARED" ]] && source "$_GROVE_PROVISION_5_3_BRAINS_SHARED"
fi

grove_provision_5_3_brains_configure_verify() {
  if ! _grove_provision_5_3_brains_verify_readers_present; then
    echo "   ✋ the 5.3.brains readers are absent from this run (the bundle's _.sh did not source)" >&2
    echo "      ⇒ the strip, the lock, and the global config path are unproven" >&2
    echo "      ⇒ the bundle driver sources _.sh beside this file, so run it through the driver" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "   ✋ jq is absent, so the settings values, the strip, and the lock are unproven" >&2
    echo "      ⇒ this bundle's provision phase installs jq, so it did not run or could not reach root" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # every claim runs — a `&&` would hide the later verdicts (`rule.forbid.failhide`)
  local failed=0
  _grove_provision_5_3_brains_settings_values_verify "$HOME/.claude/settings.json" || failed=1
  _grove_provision_5_3_brains_lock_verify || failed=1
  _grove_provision_5_3_brains_keybindings_verify || failed=1
  _grove_provision_5_3_brains_config_verify || failed=1
  return $failed
}