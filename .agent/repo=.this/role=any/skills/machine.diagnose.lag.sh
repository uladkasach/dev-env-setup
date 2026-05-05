#!/usr/bin/env bash
######################################################################
# .what = diagnose system lag via comprehensive snapshot
#
# .why  = quick triage when system feels sluggish
#         captures full snapshot for later analysis
#
# usage:
#   machine.diagnose.lag.sh             # full diagnostic + save snapshot
#   machine.diagnose.lag.sh --quick     # summary only (no disk I/O check)
######################################################################

set -uo pipefail
# note: no -e because grep returns 1 when no matches found

QUICK_MODE=0
if [[ "${1:-}" == "--quick" ]]; then
  QUICK_MODE=1
fi

# ensure snapshot command exists
if ! command -v machine_usage_snapshot &>/dev/null; then
  echo "⚠️  machine_usage_snapshot not found"
  echo "   run: source ~/git/more/dev-env-setup/src/install_env.pt1.system.performance.sh && install_machine_usage_snapshot"
  exit 1
fi

echo "🔍 capture snapshot..."
echo ""

# run snapshot and capture the output path
SNAPSHOT_OUTPUT=$(machine_usage_snapshot)
SNAPSHOT_FILE=$(echo "$SNAPSHOT_OUTPUT" | grep -oP '(?<=📸 snapshot saved: ).*' || true)

if [[ -z "$SNAPSHOT_FILE" || ! -f "$SNAPSHOT_FILE" ]]; then
  echo "⚠️  snapshot failed"
  exit 1
fi

# now output summary from the snapshot
echo "═══════════════════════════════════════════════════════════════════"
echo "📸 SNAPSHOT: $SNAPSHOT_FILE"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# quick summary - extract key sections from snapshot
echo "🐈 quick summary..."
echo ""

# load
grep -A3 "LOAD AVERAGE" "$SNAPSHOT_FILE" | tail -3 | sed 's/│/  /g' || true
echo ""

# memory
grep -A5 "MEMORY" "$SNAPSHOT_FILE" | tail -5 | sed 's/│/  /g' || true
echo ""

# cpu breakdown
grep -A1 "CPU BREAKDOWN" "$SNAPSHOT_FILE" | tail -1 | sed 's/│/  /g' || true
echo ""

# top 5 CPU
echo "🔥 top 5 cpu..."
grep -A50 "TOP 15 CPU PROCESSES" "$SNAPSHOT_FILE" | grep -E "^│ [a-zA-Z?]|pid=" | head -10 | sed 's/│/  /g' || true
echo ""

# top 5 MEM
echo "🐘 top 5 mem..."
grep -A50 "TOP 15 MEM PROCESSES" "$SNAPSHOT_FILE" | grep -E "^│ [a-zA-Z?]|pid=.*mem=" | head -10 | sed 's/│/  /g' || true
echo ""

# d-state processes
DSTATE=$(grep -A10 "D-STATE PROCESSES" "$SNAPSHOT_FILE" | grep "pid=" | head -5 || true)
if [[ -n "$DSTATE" ]]; then
  echo "⚠️  d-state (blocked on I/O)..."
  echo "$DSTATE" | sed 's/│/  /g'
  echo ""
fi

# zombies
ZOMBIES=$(grep -A10 "ZOMBIE PROCESSES" "$SNAPSHOT_FILE" | grep "pid=" | head -5 || true)
if [[ -n "$ZOMBIES" ]]; then
  echo "🧟 zombies..."
  echo "$ZOMBIES" | sed 's/│/  /g'
  echo ""
fi

if [[ $QUICK_MODE -eq 0 ]]; then
  # disk I/O
  DISK_IO=$(grep -A12 "DISK I/O" "$SNAPSHOT_FILE" | tail -10 || true)
  if [[ -n "$DISK_IO" ]]; then
    echo "💾 disk I/O..."
    echo "$DISK_IO" | sed 's/│/  /g'
    echo ""
  fi
fi

# temperatures - show if any are hot
TEMPS=$(grep -A10 "TEMPERATURES" "$SNAPSHOT_FILE" | grep -E "[0-9]+°C" | head -5 || true)
if [[ -n "$TEMPS" ]]; then
  echo "🌡️  temperatures..."
  echo "$TEMPS" | sed 's/│/  /g'
  echo ""
fi

echo "═══════════════════════════════════════════════════════════════════"
echo "📖 full snapshot: cat $SNAPSHOT_FILE"
echo "═══════════════════════════════════════════════════════════════════"
