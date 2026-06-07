#!/usr/bin/env bash
######################################################################
# .what = detect and diagnose runaway nvim processes
#
# .why  = nvim can hang from treesitter loops, timer polls, or memory leaks
#         this skill finds suspects and optionally runs strace
#
# usage:
#   nvim.diagnose.runaway.sh              # list suspect nvim processes
#   nvim.diagnose.runaway.sh --strace     # strace the worst offender
#   nvim.diagnose.runaway.sh --kill       # kill all runaway nvim
#   nvim.diagnose.runaway.sh --kill <PID> # kill specific nvim
#
# thresholds:
#   CPU > 5% when idle = suspicious
#   MEM > 1GB = suspicious
#   TIME+ > 10 min = suspicious
######################################################################

set -euo pipefail

MODE="${1:-list}"
TARGET_PID="${2:-}"

# thresholds
CPU_THRESHOLD=5
MEM_THRESHOLD_MB=1024
TIME_THRESHOLD_MIN=10

echo "🐢 nvim runaway detector"
echo ""

# get nvim processes with stats
NVIM_PROCS=$(ps -eo pid,pcpu,pmem,rss,etime,comm --sort=-pcpu | grep -E '^\s*[0-9]+.*nvim' | grep -v grep || true)

if [[ -z "$NVIM_PROCS" ]]; then
  echo "✨ no nvim processes found"
  exit 0
fi

echo "📊 nvim processes:"
echo ""
printf "  %-8s %-6s %-6s %-10s %-12s %s\n" "PID" "CPU%" "MEM%" "RSS(MB)" "TIME" "STATUS"
echo "  ────────────────────────────────────────────────────────────"

SUSPECT_PIDS=()

while read -r line; do
  PID=$(echo "$line" | awk '{print $1}')
  CPU=$(echo "$line" | awk '{print $2}' | cut -d. -f1)
  MEM_PCT=$(echo "$line" | awk '{print $3}')
  RSS_KB=$(echo "$line" | awk '{print $4}')
  ETIME=$(echo "$line" | awk '{print $5}')

  RSS_MB=$((RSS_KB / 1024))

  # parse elapsed time (formats: MM:SS, HH:MM:SS, D-HH:MM:SS)
  if [[ "$ETIME" =~ ^([0-9]+)-([0-9]+):([0-9]+):([0-9]+)$ ]]; then
    DAYS=${BASH_REMATCH[1]}
    HOURS=${BASH_REMATCH[2]}
    MINS=${BASH_REMATCH[3]}
    TOTAL_MINS=$((DAYS * 1440 + HOURS * 60 + MINS))
  elif [[ "$ETIME" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
    HOURS=${BASH_REMATCH[1]}
    MINS=${BASH_REMATCH[2]}
    TOTAL_MINS=$((HOURS * 60 + MINS))
  elif [[ "$ETIME" =~ ^([0-9]+):([0-9]+)$ ]]; then
    MINS=${BASH_REMATCH[1]}
    TOTAL_MINS=$MINS
  else
    TOTAL_MINS=0
  fi

  # determine status
  STATUS=""
  IS_SUSPECT=0

  if [[ $CPU -gt $CPU_THRESHOLD ]]; then
    STATUS="🔥 high CPU"
    IS_SUSPECT=1
  fi

  if [[ $RSS_MB -gt $MEM_THRESHOLD_MB ]]; then
    [[ -n "$STATUS" ]] && STATUS="$STATUS, "
    STATUS="${STATUS}🐘 high MEM"
    IS_SUSPECT=1
  fi

  if [[ $TOTAL_MINS -gt $TIME_THRESHOLD_MIN && $CPU -gt 0 ]]; then
    [[ -n "$STATUS" ]] && STATUS="$STATUS, "
    STATUS="${STATUS}⏱️ long run"
    IS_SUSPECT=1
  fi

  [[ -z "$STATUS" ]] && STATUS="✓ ok"

  printf "  %-8s %-6s %-6s %-10s %-12s %s\n" "$PID" "$CPU" "$MEM_PCT" "$RSS_MB" "$ETIME" "$STATUS"

  if [[ $IS_SUSPECT -eq 1 ]]; then
    SUSPECT_PIDS+=("$PID")
  fi

done <<< "$NVIM_PROCS"

echo ""

if [[ ${#SUSPECT_PIDS[@]} -eq 0 ]]; then
  echo "✨ no suspects found"
  exit 0
fi

echo "⚠️  suspects: ${SUSPECT_PIDS[*]}"
echo ""

case "$MODE" in
  --strace)
    WORST_PID="${SUSPECT_PIDS[0]}"
    echo "🔍 strace on PID $WORST_PID (first 50 lines)..."
    echo ""
    sudo strace -p "$WORST_PID" -f 2>&1 | head -50 || true
    echo ""
    echo "💡 tip: look for repeated getcwd(), epoll_pwait(..., 0, ...), or ftplugin loops"
    ;;

  --kill)
    if [[ -n "$TARGET_PID" ]]; then
      echo "🗡️  kill -9 $TARGET_PID"
      kill -9 "$TARGET_PID"
    else
      echo "🗡️  kill all suspects..."
      for pid in "${SUSPECT_PIDS[@]}"; do
        echo "  kill -9 $pid"
        kill -9 "$pid" || true
      done
    fi
    echo "✅ done"
    ;;

  *)
    echo "💡 commands:"
    echo "  nvim.diagnose.runaway.sh --strace     # strace worst offender"
    echo "  nvim.diagnose.runaway.sh --kill       # kill all suspects"
    echo "  nvim.diagnose.runaway.sh --kill <PID> # kill specific"
    ;;
esac
