#!/usr/bin/env bash
# .what = install debian's waypipe, idempotently, via pkg_install
# .why  = `pkg_install`, never a bare `apt install` — asserts the debian
#   invariant and skips the ask entirely once the package already holds

grove_provision_5_22_waypipe_provision_upsert() {
  pkg_install waypipe || return 1
  echo "   • waypipe ✔"
}
