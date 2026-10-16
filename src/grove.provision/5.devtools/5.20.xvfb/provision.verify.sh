#!/usr/bin/env bash
######################################################################
# .what = prove Xvfb and x11vnc are on PATH, and that x11vnc does NOT run
#
# .why the second claim — x11vnc serves a screen over the network; the
#   install must leave it dormant, so a human starts it per need
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_20_xvfb_provision_verify() {
  local failed=0 bin
  for bin in Xvfb x11vnc; do
    command -v "$bin" >/dev/null 2>&1 && continue
    echo "   ✋ $bin is absent from PATH" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 5.20.xvfb --mode apply" >&2
    echo "           (on a grove: run it on the ground seat, which holds sudo)" >&2
    failed=1
  done
  (( failed == 0 )) || return 1

  # x11vnc must not run, nor be armed to start at boot
  if pgrep -x x11vnc >/dev/null 2>&1 || systemctl is-enabled x11vnc.service >/dev/null 2>&1; then
    echo "   ✋ x11vnc runs or is enabled — a vnc listener this bundle never asked for" >&2
    echo "      ⇒ it serves a screen over the network; start it per need, bound to localhost" >&2
    echo "      read why: pgrep -a x11vnc; systemctl status x11vnc.service" >&2
    return 1
  fi

  echo "   • Xvfb + x11vnc are present, and x11vnc is dormant ✔"
}
