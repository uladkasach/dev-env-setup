#!/usr/bin/env bash
######################################################################
# .what = prove waypipe is on PATH and answers its version
#
# .why the version — `waypipe ssh` needs a compatible waypipe on BOTH ends,
#   so the verify prints it; a client/server mismatch reads off two plans
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_22_waypipe_provision_verify() {
  if ! command -v waypipe >/dev/null 2>&1; then
    echo "   ✋ waypipe is absent from PATH" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 5.22.waypipe --mode apply" >&2
    echo "           (on a grove: run it on the ground seat, which holds sudo)" >&2
    return 1
  fi

  local version
  if ! version="$(waypipe --version 2>&1)"; then
    echo "   ✋ waypipe is on PATH but --version failed: $version" >&2
    return 1
  fi

  # keep the version line alone; the feature lines below it are noise here
  version="${version%%$'\n'*}"

  echo "   • waypipe is present ($version) ✔"
}
