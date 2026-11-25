#!/usr/bin/env bash
######################################################################
# .what = prove jq is on this seat and parses — the meter classifier and writer
#         both read with it
#
# .why  = the upsert's exit says its last command returned 0, never that jq is
#         reachable. with no usable jq, every read would call a healthy meter
#         damaged (`rule.require.upgrade-entries-verify-themselves`)
#
# exit:
#   0 = jq is on PATH and reads a json object as one
#   1 = jq is absent or does not parse; the apply that converges it is named
######################################################################

grove_provision_5_26_commitorgs_provision_verify() {
  grove_provision_5_26_commitorgs_declines >/dev/null && return 0

  if ! grove_provision_5_26_commitorgs_has_jq; then
    echo "   ✋ ConstraintError: jq is absent on $(whoami)@$(hostname), so the org commit meter cannot be read" >&2
    echo "      ├─ why: the meter's reader and writer both parse with jq" >&2
    echo "      └─ fix: rhx grove.provision --what 5.26.commitorgs --mode apply   # its upsert installs jq" >&2
    return 1
  fi

  # present is not usable: a parse of a known object proves the classifier's own call
  if ! printf '{"orgs":{}}' | jq -s -e '.[0] | type == "object"' >/dev/null 2>&1; then
    echo "   ✋ ConstraintError: jq on $(whoami)@$(hostname) does not parse a json object, so the meter cannot be read" >&2
    echo "      ├─ found: $(command -v jq)" >&2
    echo "      └─ fix: rhx grove.provision --what 5.26.commitorgs --mode apply   # its upsert installs jq" >&2
    return 1
  fi

  echo "   • jq parses json on this seat ✔"
}
