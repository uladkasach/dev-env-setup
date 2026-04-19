#!/usr/bin/env bash
#########################
## verify_isolation.sh
##
## verifies that host processes cannot access firefox flatpak memory.
## tests: yama ptrace_scope, ptrace attach, /proc/pid/mem read.
##
## usage:
##   ./tests/verify_isolation.sh
##
## prereqs:
##   - strace installed
##   - firefox flatpak active
##
## exit codes:
##   0 = all tests passed
##   1 = one or more tests failed
##   2 = prereqs not met
#########################

set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

# check prereqs
check_prereqs() {
  if ! command -v strace &>/dev/null; then
    echo "[PREREQ] strace not installed"
    echo "         install with: sudo apt install strace"
    exit 2
  fi
  echo "[PREREQ] strace installed"
}

# find firefox flatpak pid
find_firefox_pid() {
  local pid

  # try pgrep first
  pid=$(pgrep -f "firefox.*flatpak" 2>/dev/null | head -1) || true

  # fallback to flatpak ps
  if [[ -z "$pid" ]]; then
    pid=$(flatpak ps 2>/dev/null | grep -i firefox | awk '{print $1}' | head -1) || true
  fi

  if [[ -z "$pid" ]]; then
    echo "[PREREQ] firefox flatpak not active"
    echo "         start with: flatpak run org.mozilla.firefox"
    exit 2
  fi

  echo "$pid"
}

# test yama ptrace_scope
test_yama_scope() {
  local scope
  scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null) || scope="unknown"

  if [[ "$scope" == "2" ]]; then
    echo "[PASS] yama ptrace_scope = 2 (admin-only)"
    ((PASS_COUNT++))
  else
    echo "[FAIL] yama ptrace_scope = $scope (expected 2)"
    ((FAIL_COUNT++))
  fi
}

# test ptrace attach blocked
test_ptrace_blocked() {
  local pid="$1"
  local output

  # attempt strace attach, should fail
  output=$(strace -p "$pid" 2>&1 & sleep 0.5; kill $! 2>/dev/null) || true

  if echo "$output" | grep -qi "operation not permitted\|EPERM\|attach: ptrace"; then
    echo "[PASS] ptrace attach blocked"
    ((PASS_COUNT++))
  else
    echo "[FAIL] ptrace attach may have succeeded"
    echo "       output: $output"
    ((FAIL_COUNT++))
  fi
}

# test /proc/pid/mem read blocked
test_proc_mem_blocked() {
  local pid="$1"
  local result

  # attempt to read process memory
  if head -c 1 "/proc/$pid/mem" 2>/dev/null; then
    echo "[FAIL] /proc/$pid/mem readable"
    ((FAIL_COUNT++))
  else
    echo "[PASS] /proc/$pid/mem blocked"
    ((PASS_COUNT++))
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
  echo "verify_isolation: check host-to-sandbox isolation"
  echo ""

  check_prereqs

  echo ""
  echo "find firefox flatpak pid..."
  local firefox_pid
  firefox_pid=$(find_firefox_pid)
  echo "found firefox pid: $firefox_pid"
  echo ""

  test_yama_scope
  test_ptrace_blocked "$firefox_pid"
  test_proc_mem_blocked "$firefox_pid"

  report_results
}

main "$@"
