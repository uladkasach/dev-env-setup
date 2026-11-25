#!/usr/bin/env bash
######################################################################
# .what = put `jq` on this seat; the meter reader and writer parse with it
# .why  = with no jq a healthy meter reads as damaged
#         (`rule.require.bundles-own-their-dependencies`)
######################################################################

grove_provision_5_26_commitorgs_provision_upsert() {
  grove_provision_5_26_commitorgs_declines >/dev/null && return 0
  grove_provision_5_26_commitorgs_has_jq && return 0

  if ! pkg_install jq; then
    echo "   ✋ ConstraintError: jq could not be installed on $(whoami)@$(hostname)" >&2
    echo "      ├─ why: the meter's reader and writer both parse with jq" >&2
    echo "      └─ fix: read the install's own error above, then re-run — rhx grove.provision --what 5.26.commitorgs --mode apply" >&2
    return 1
  fi
  echo "   • jq installed — 5.26 reads and writes the org commit meter with it"
}
