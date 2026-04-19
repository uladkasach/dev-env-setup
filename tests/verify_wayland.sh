#!/usr/bin/env bash
#########################
## verify_wayland.sh
##
## verifies that firefox flatpak uses wayland, not x11.
## tests: x11 socket denied, wayland socket allowed.
##
## usage:
##   ./tests/verify_wayland.sh
##
## prereqs:
##   - firefox flatpak installed
##
## exit codes:
##   0 = all tests passed
##   1 = one or more tests failed
##   2 = prereqs not met
#########################

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

# test x11 socket denied
test_x11_socket_denied() {
  local output

  # check if x11 socket visible inside flatpak
  output=$(flatpak run --command=ls org.mozilla.firefox /tmp/.X11-unix 2>&1) || true

  if [[ -z "$output" ]] || echo "$output" | grep -qi "no such file\|cannot access"; then
    echo "[PASS] x11 socket not visible to firefox"
    ((PASS_COUNT++))
  else
    echo "[FAIL] x11 socket visible to firefox"
    echo "       output: $output"
    ((FAIL_COUNT++))
  fi
}

# test wayland socket allowed
test_wayland_socket_allowed() {
  local output

  # check flatpak permissions for wayland
  output=$(flatpak info --show-permissions org.mozilla.firefox 2>/dev/null) || true

  if echo "$output" | grep -q "socket=wayland"; then
    echo "[PASS] wayland socket allowed"
    ((PASS_COUNT++))
  else
    echo "[FAIL] wayland socket not found in permissions"
    echo "       check: flatpak info --show-permissions org.mozilla.firefox"
    ((FAIL_COUNT++))
  fi
}

# test x11 sockets explicitly denied
test_x11_sockets_denied() {
  local output

  output=$(flatpak override --user --show org.mozilla.firefox 2>/dev/null) || true

  local x11_denied=0
  local fallback_denied=0

  if echo "$output" | grep -q "nosocket=x11"; then
    x11_denied=1
  fi
  if echo "$output" | grep -q "nosocket=fallback-x11"; then
    fallback_denied=1
  fi

  if [[ "$x11_denied" == "1" ]] && [[ "$fallback_denied" == "1" ]]; then
    echo "[PASS] x11 and fallback-x11 sockets denied via override"
    ((PASS_COUNT++))
  else
    echo "[FAIL] x11 socket overrides not set"
    echo "       x11 denied: $x11_denied, fallback-x11 denied: $fallback_denied"
    ((FAIL_COUNT++))
  fi
}

# report results
report_results() {
  echo ""
  echo "=========================================="
  echo "results: $PASS_COUNT passed, $FAIL_COUNT failed"
  echo "=========================================="

  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

# main
main() {
  echo "verify_wayland: check wayland isolation"
  echo ""

  test_x11_socket_denied
  test_wayland_socket_allowed
  test_x11_sockets_denied

  report_results
}

main "$@"
