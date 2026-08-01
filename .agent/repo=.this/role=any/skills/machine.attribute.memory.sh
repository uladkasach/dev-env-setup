#!/usr/bin/env bash
######################################################################
# .what = attribute memory to the cgroup that OWNS it, not the process
#         name that happens to hold it
#
# .why  = `ps` aggregation by comm lies about origin. it says "node
#         ×686, 14.5G" — which names the binary, not the culprit. the
#         processes that spawned those node children have often exited,
#         so ps shows them reparented to systemd (PPid 1/2455) with no
#         trace of who forked them.
#
#         cgroups do not lie. cgroup membership is assigned at fork and
#         SURVIVES reparent to systemd. so a node orphan still sits in
#         the scope of the session that spawned it, and the scope's
#         memory.current still counts it. that makes the cgroup the
#         true unit of attribution.
#
#         this also surfaces two things ps cannot see at all:
#           - zombie cgroups: removed cgroups whose pages stay charged.
#             they hold memory with ZERO live processes, so they are
#             invisible to any process-level tool.
#           - anon vs file split per scope, which separates a real
#             heap leak (anon grows) from page cache (file, harmless).
#
# usage:
#   machine.attribute.memory.sh                 # top scopes by memory
#   machine.attribute.memory.sh --top 30        # show more scopes
#   machine.attribute.memory.sh --scope $name   # drill into one scope
#   machine.attribute.memory.sh --orphans       # only reparented procs
#   machine.attribute.memory.sh --zombies       # zombie-cgroup report
#
# guarantee:
#   - read-only; no kill, no mutation, no config change
#   - needs no root (reads own user slice)
#   - fail-fast on bad input
######################################################################

set -euo pipefail

CGROOT="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service"
TOP=15
MODE="scopes"
SCOPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --top) TOP="${2:-}"; shift 2 ;;
    --scope) SCOPE="${2:-}"; MODE="drill"; shift 2 ;;
    --orphans) MODE="orphans"; shift ;;
    --zombies) MODE="zombies"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$CGROOT" ]] || { echo "💥 no cgroup v2 user slice at $CGROOT" >&2; exit 1; }

# bytes -> human units, so the numbers stay scannable
as_human() {
  local b="${1:-0}"
  awk -v b="$b" 'BEGIN{
    split("B K M G T", u, " ")
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d%s" : "%.1f%s"), b, u[i]
  }'
}

read_or_zero() { cat "$1" 2>/dev/null || echo 0; }

# pull one field out of a cgroup memory.stat
stat_field() {
  awk -v k="$2" '$1 == k { print $2; exit }' "$1" 2>/dev/null || echo 0
}

# ── mode: scopes ── rank every cgroup by what it is charged for
report_scopes() {
  echo "🐢 lets see who really holds it..."
  echo ""
  echo "🐚 machine.attribute.memory --top $TOP"

  local total_anon=0 total_file=0 rows=""

  while IFS= read -r dir; do
    local mem swap pids anon file name
    mem=$(read_or_zero "$dir/memory.current")
    [[ "$mem" -lt 1048576 ]] && continue   # skip sub-1M noise
    swap=$(read_or_zero "$dir/memory.swap.current")
    pids=$(read_or_zero "$dir/pids.current")
    anon=$(stat_field "$dir/memory.stat" anon)
    file=$(stat_field "$dir/memory.stat" file)
    name="${dir#"$CGROOT"/}"
    total_anon=$((total_anon + anon))
    total_file=$((total_file + file))
    rows+="$mem|$swap|$pids|$anon|$name"$'\n'
  done < <(find "$CGROOT" -type d 2>/dev/null)

  echo "   ├─ totals"
  echo "   │  ├─ anon (heap, needs swap): $(as_human "$total_anon")"
  echo "   │  └─ file (cache, droppable): $(as_human "$total_file")"
  echo "   └─ top scopes by charge"
  echo "      ├─"
  echo "      │"
  printf '      │  %-10s %-9s %-6s %-9s %s\n' "MEMORY" "SWAP" "PIDS" "ANON" "SCOPE"

  echo "$rows" | sort -t'|' -k1 -rn | head -n "$TOP" | while IFS='|' read -r mem swap pids anon name; do
    [[ -z "$name" ]] && continue
    printf '      │  %-10s %-9s %-6s %-9s %s\n' \
      "$(as_human "$mem")" "$(as_human "$swap")" "$pids" "$(as_human "$anon")" "${name:0:48}"
  done

  echo "      │"
  echo "      └─"
  echo ""
  echo "💡 anon is the leak signal — file is page cache and reclaims for free."
  echo "   drill in with: --scope <name>"
}

# ── mode: drill ── all procs charged to one scope, orphans marked
report_drill() {
  local dir="$CGROOT/$SCOPE"
  [[ -d "$dir" ]] || { echo "✋ no such scope: $SCOPE" >&2; exit 2; }

  echo "🐢 lets crack this one open..."
  echo ""
  echo "🐚 machine.attribute.memory --scope ${SCOPE:0:50}"
  echo "   ├─ memory: $(as_human "$(read_or_zero "$dir/memory.current")")"
  echo "   ├─ swap:   $(as_human "$(read_or_zero "$dir/memory.swap.current")")"
  echo "   ├─ peak:   $(as_human "$(read_or_zero "$dir/memory.peak")")"
  echo "   ├─ pids:   $(read_or_zero "$dir/pids.current")"
  echo "   └─ procs charged here"
  echo "      ├─"
  echo "      │"
  printf '      │  %-9s %-9s %-8s %-7s %s\n' "PID" "RSS" "SWAP" "PPID" "CMD"

  local sysd
  sysd=$(pgrep -u "$(id -u)" -x systemd | head -1 || echo 0)

  while IFS= read -r pid; do
    [[ -z "$pid" || ! -d "/proc/$pid" ]] && continue
    local rss vmswap ppid cmd flag
    rss=$(awk '/^VmRSS:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
    vmswap=$(awk '/^VmSwap:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
    ppid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
    cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-42 || true)
    [[ -z "$cmd" ]] && cmd=$(cat "/proc/$pid/comm" 2>/dev/null || echo "?")
    # ppid 1 or the user systemd = reparented, i.e. its spawner died
    flag=""
    [[ "$ppid" == "1" || "$ppid" == "$sysd" ]] && flag=" 🔗orphan"
    printf '      │  %-9s %-9s %-8s %-7s %s%s\n' \
      "$pid" "$(as_human $((rss * 1024)))" "$(as_human $((vmswap * 1024)))" "$ppid" "$cmd" "$flag"
  done < <(cat "$dir/cgroup.procs" 2>/dev/null)

  echo "      │"
  echo "      └─"
  echo ""
  echo "💡 🔗orphan = spawner already exited; the proc lives on, still charged here."
}

# ── mode: orphans ── reparented procs across every scope
report_orphans() {
  echo "🐢 lets find the strays..."
  echo ""
  echo "🐚 machine.attribute.memory --orphans"
  echo "   └─ procs whose spawner exited (still charged to their scope)"
  echo "      ├─"
  echo "      │"

  local sysd
  sysd=$(pgrep -u "$(id -u)" -x systemd | head -1 || echo 0)

  printf '      │  %-9s %-9s %-22s %s\n' "PID" "RSS" "CMD" "SCOPE"
  while IFS= read -r pid; do
    [[ -d "/proc/$pid" ]] || continue
    local ppid rss cmd cg
    ppid=$(awk '/^PPid:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
    [[ "$ppid" == "1" || "$ppid" == "$sysd" ]] || continue
    rss=$(awk '/^VmRSS:/{print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)
    [[ "$rss" -lt 1024 ]] && continue
    cmd=$(cat "/proc/$pid/comm" 2>/dev/null || echo "?")
    cg=$(awk -F/ '{print $NF}' "/proc/$pid/cgroup" 2>/dev/null || echo "?")
    printf '      │  %-9s %-9s %-22s %s\n' \
      "$pid" "$(as_human $((rss * 1024)))" "${cmd:0:22}" "${cg:0:40}"
  done < <(ps -eo pid --no-headers | tr -d ' ') | sort -k2 -h -r | head -n "$TOP"

  echo "      │"
  echo "      └─"
  echo ""
  echo "💡 many orphans of one binary = a spawn path that fails to reap."
  echo "   that is a leak to fix at source, not to cap."
}

# ── mode: zombies ── cgroups removed but still charged
report_zombies() {
  echo "🐢 lets check the ghosts..."
  echo ""
  echo "🐚 machine.attribute.memory --zombies"

  local zombie live
  # nr_dying_descendants is the literal kernel field name for these
  zombie=$(awk '/^nr_dying_descendants/{print $2}' "$CGROOT/cgroup.stat" 2>/dev/null || echo 0)
  live=$(awk '/^nr_descendants/{print $2}' "$CGROOT/cgroup.stat" 2>/dev/null || echo 0)

  echo "   ├─ live cgroups:   $live"
  echo "   ├─ zombie cgroups: $zombie"
  echo "   └─ what this means"
  echo "      ├─"
  echo "      │"
  echo "      │  a zombie cgroup was removed, but the kernel still holds"
  echo "      │  charged pages for it — usually page cache or socket memory"
  echo "      │  pinned by a reference the kernel has not dropped."
  echo "      │"
  echo "      │  they have ZERO live processes, so no process-level tool"
  echo "      │  (ps, top, htop) can see them. they are pure overhead."
  echo "      │"
  if [[ "$zombie" -gt 50 ]]; then
    echo "      │  ⚠️  $zombie is high. each one pins slab + cache. this"
    echo "      │  accrues when many short-lived scopes churn — e.g. one"
    echo "      │  scope per tool call."
  fi
  echo "      │"
  echo "      └─"
  echo ""
  echo "💡 zombie cgroups clear on memory pressure or reboot. a high count"
  echo "   with high scope churn points at a spawn pattern to fix."
}

case "$MODE" in
  scopes) report_scopes ;;
  drill) report_drill ;;
  orphans) report_orphans ;;
  zombies) report_zombies ;;
esac
