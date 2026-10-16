#!/usr/bin/env bash
# .what = install debian's xvfb and x11vnc, idempotently, via pkg_install
# .why  = `pkg_install`, never a bare `apt install` — asserts the debian
#   invariant and skips the ask entirely once both packages already hold

grove_provision_5_20_xvfb_provision_upsert() {
  pkg_install xvfb x11vnc || return 1
  echo "   • xvfb + x11vnc ✔"
}
