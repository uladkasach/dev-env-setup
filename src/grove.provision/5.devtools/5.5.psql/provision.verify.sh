#!/usr/bin/env bash
######################################################################
# .what = prove psql is on PATH
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_5_psql_provision_verify() {
  if command -v psql >/dev/null 2>&1; then
    echo "   • psql is on PATH ✔ ($(psql --version 2>/dev/null))"
    return 0
  fi

  echo "   ✋ psql is absent from PATH" >&2
  echo "      ⇒ no database this repo declares can be reached from this box" >&2
  echo "      fix: rhx grove.provision --what 5.5.psql --mode apply" >&2
  return 1
}
