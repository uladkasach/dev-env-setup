#!/usr/bin/env bash
######################################################################
# .what = prove pqiv is on PATH
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_4_6_pqiv_provision_verify() {
  if ! command -v pqiv >/dev/null 2>&1; then
    echo "   ✋ pqiv is absent from PATH" >&2
    echo "      fix: rhx grove.provision --what 4.6.pqiv --mode apply" >&2
    return 1
  fi

  echo "   • pqiv is present ✔ ($(command -v pqiv))"
}
