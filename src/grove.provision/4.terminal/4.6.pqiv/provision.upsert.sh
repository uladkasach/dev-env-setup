#!/usr/bin/env bash
# .what = install debian's pqiv, idempotently, via pkg_install
# .why  = `pkg_install`, never a bare `apt install` — asserts the debian
#   invariant and skips the ask entirely once the package already holds

grove_provision_4_6_pqiv_provision_upsert() {
  pkg_install pqiv || return 1
  echo "   • pqiv ✔"
}
