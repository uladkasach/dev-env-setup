#!/usr/bin/env bash
######################################################################
# .what = inspect a live nvim (esp. `nvim --embed`) to reveal
#         (1) what spawned it and (2) what it is spinning/blocked on
#
# .why  = killing a runaway nvim destroys the evidence. before we
#         reap, we inspect. most of this needs no root — it reads
#         /proc for your own processes:
#           - parent chain      -> reveals the embedder (the GUI/tool
#                                  that launched `nvim --embed` over rpc)
#           - environ           -> launcher fingerprint (TERM_PROGRAM,
#                                  KITTY_*, TMUX, NVIM_*, VSCODE_*, etc)
#           - per-thread wchan  -> the kernel wait-channel each thread
#                                  sits in (what it's blocked on)
#           - per-thread cpu    -> which thread burns cpu (the hot loop)
#           - fd/socket peers   -> who is attached over the rpc pipe
#
# usage:
#   nvim.inspect.embed.sh                 # inspect worst nvim by cpu
#   nvim.inspect.embed.sh --pid 538557    # inspect a specific pid
#   nvim.inspect.embed.sh --all           # inspect every nvim
#   nvim.inspect.embed.sh --pid 538557 --strace   # + short strace sample
#
# guarantee:
#   - read-only by default (no kill, no mutation)
#   - /proc reads need no root for your own processes
#   - --strace is best-effort (needs sudo; skipped if unavailable)
#   - fail-fast on bad input
######################################################################

set -euo pipefail

PID=""
MODE="worst"
DO_STRACE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pid) PID="${2:-}"; MODE="pid"; shift 2 ;;
    --all) MODE="all"; shift ;;
    --strace) DO_STRACE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "⛈️  unknown arg: $1" >&2; exit 2 ;;
  esac
done

# get target pids
get_target_pids() {
  case "$MODE" in
    pid)
      [[ -z "$PID" ]] && { echo "⛈️  --pid requires a value" >&2; exit 2; }
      [[ -d "/proc/$PID" ]] || { echo "⛈️  no such process: $PID" >&2; exit 2; }
      echo "$PID"
      ;;
    all)
      ps -eo pid,comm --sort=-pcpu | awk '$2 ~ /nvim/ {print $1}'
      ;;
    worst)
      ps -eo pid,pcpu,comm --sort=-pcpu | awk '$3 ~ /nvim/ {print $1; exit}'
      ;;
  esac
}

# clk ticks per second (for cpu-time math)
CLK=$(getconf CLK_TCK 2>/dev/null)
[[ -z "$CLK" ]] && CLK=100

read_field() { # file, key
  awk -v k="$1:" '$1==k {print $2; exit}' "$2" 2>/dev/null
}

inspect_one() {
  local pid="$1"
  local statusf="/proc/$pid/status"
  [[ -r "$statusf" ]] || { echo "⛈️  cannot read $statusf (gone or not yours)" >&2; return 1; }

  local comm ppid threads rss state
  comm=$(read_field Name "$statusf")
  ppid=$(read_field PPid "$statusf")
  threads=$(read_field Threads "$statusf")
  rss=$(read_field VmRSS "$statusf")
  state=$(read_field State "$statusf")

  echo "════════════════════════════════════════════════════════════"
  echo "🔬 pid=$pid  name=$comm  state=$state  threads=$threads  rss=${rss:-?}kB"
  echo "   cmd: $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
  echo "   cwd: $(readlink "/proc/$pid/cwd" 2>/dev/null || echo '?')"
  echo ""

  # ── who spawned it: walk the parent chain ──
  echo "👪 parent chain (spawner is the top non-shell/non-init):"
  local cur="$ppid" depth=0
  while [[ -n "$cur" && "$cur" != "0" && $depth -lt 12 ]]; do
    local pstat="/proc/$cur/status"
    [[ -r "$pstat" ]] || { echo "   └─ $cur (gone)"; break; }
    local pcomm pcmd
    pcomm=$(read_field Name "$pstat")
    pcmd=$(tr '\0' ' ' < "/proc/$cur/cmdline" 2>/dev/null)
    printf "   ├─ %-8s %-18s %s\n" "$cur" "$pcomm" "${pcmd:0:70}"
    cur=$(read_field PPid "$pstat")
    depth=$((depth+1))
  done
  echo ""

  # ── launcher fingerprint from environ (own process = readable) ──
  echo "🧬 environ fingerprint (who set up this nvim's world):"
  if [[ -r "/proc/$pid/environ" ]]; then
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
      | grep -iE '^(TERM|TERM_PROGRAM|TERMINAL|KITTY_|GHOSTTY|WEZTERM|ALACRITTY|TMUX|STY|NVIM|VIM|MYVIMRC|VIMRUNTIME|VSCODE_|NEOVIDE_|GONEOVIM|FVIM|NODE|npm_|PWD|WINDOWID|DISPLAY|WAYLAND_DISPLAY|_)=' \
      | sed 's/^/   /' | head -40 || echo "   (no matching vars)"
  else
    echo "   (environ not readable)"
  fi
  echo ""

  # ── per-thread: state, wchan (what it's blocked on), cpu time ──
  echo "🧵 threads (state | wchan = what it's waiting on | cpu-secs):"
  printf "   %-8s %-5s %-24s %s\n" "TID" "ST" "WCHAN" "CPU_s"
  local t tid tstate wchan utime stime cpus
  for t in /proc/"$pid"/task/*; do
    [[ -d "$t" ]] || continue
    tid=$(basename "$t")
    # stat fields: 3=state 14=utime 15=stime
    read -r tstate utime stime < <(awk '{print $3, $14, $15}' "$t/stat" 2>/dev/null)
    wchan=$(cat "$t/wchan" 2>/dev/null || echo '?')
    [[ -z "$wchan" || "$wchan" == "0" ]] && wchan="(running/userspace)"
    cpus=$(awk -v u="${utime:-0}" -v s="${stime:-0}" -v c="$CLK" 'BEGIN{printf "%.1f",(u+s)/c}')
    printf "   %-8s %-5s %-24s %s\n" "$tid" "$tstate" "$wchan" "$cpus"
  done
  echo ""

  # ── rpc/socket peers: who is attached over the embed pipe ──
  echo "🔌 fd targets (stdio pipe = the embedder; sockets = rpc/lsp):"
  local fd
  for fd in /proc/"$pid"/fd/0 /proc/"$pid"/fd/1 /proc/"$pid"/fd/2; do
    [[ -e "$fd" ]] && printf "   fd %-2s -> %s\n" "$(basename "$fd")" "$(readlink "$fd" 2>/dev/null)"
  done
  # count + sample socket fds
  ls -l /proc/"$pid"/fd 2>/dev/null | awk '/socket:/ {print "   sock  -> "$NF}' | head -8 || true
  echo ""

  # ── optional strace sample (needs sudo) ──
  if [[ $DO_STRACE -eq 1 ]]; then
    echo "🕵️  strace sample (2s, needs sudo — the actual hot syscalls):"
    if command -v strace >/dev/null 2>&1; then
      timeout 2 sudo strace -f -p "$pid" -e trace=all -c 2>/tmp/nvim-inspect-strace."$pid" || true
      sed 's/^/   /' /tmp/nvim-inspect-strace."$pid" 2>/dev/null | head -30 || echo "   (strace produced no output / permission denied)"
    else
      echo "   (strace not installed)"
    fi
    echo ""
  fi
}

echo "🐢 nvim embed inspector — evidence before we reap"
echo ""

FOUND=0
for p in $(get_target_pids); do
  FOUND=1
  inspect_one "$p" || true
done

if [[ $FOUND -eq 0 ]]; then
  echo "✨ no nvim processes found"
  exit 0
fi

echo "💡 read the WCHAN column: a thread pinned at '(running/userspace)' with"
echo "   high cpu-secs is your hot loop; the parent chain names the spawner."
