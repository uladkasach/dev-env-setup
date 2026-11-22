#!/usr/bin/env bash
######################################################################
# .what = declare claude-code's TWO config files — its settings, and its global config
# .refs = the patch, its operations, and their why: this bundle's `_.sh`, under
#         `.what = the operations configure.upsert composes`
######################################################################

# .why every half runs — a `&&` would hide the later verdicts (`rule.forbid.failhide`)
grove_provision_5_3_brains_configure_upsert() {
  local failed=0
  _grove_provision_5_3_brains_settings_step || failed=1
  _grove_provision_5_3_brains_config_upsert || failed=1
  _grove_provision_5_3_brains_keybindings_upsert || failed=1
  return $failed
}
