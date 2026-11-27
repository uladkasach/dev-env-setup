#!/usr/bin/env bash
# .what = install debian's xvfb, x11vnc, and xdotool, idempotently, via pkg_install
# .why  = `pkg_install`, never a bare `apt install` — asserts the debian
#   invariant and skips the ask entirely once every package already holds

grove_provision_5_20_xvfb_provision_upsert() {
  pkg_install xvfb x11vnc xdotool || return 1
  echo "   • xvfb + x11vnc + xdotool ✔"
}
