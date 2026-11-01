#!/usr/bin/env bash
######################################################################
# .what = read the live tmux server: its sessions, its clients, the status
#         settings that make it fork on a clock, and what it forks right now
#
# .why  = the tmux server is the largest host in a churn storm
#         (`machine.diagnose.churn` ranks it as a host, never a culprit), and
#         the question that follows is always the same: WHAT does it fork, and
#         on what clock? a status `#()` job runs through `default-shell` once
#         per `status-interval` per client, so sessions × clients × jobs is
#         the rate — and every one of those factors is a live read
#
# usage:
#   tmux.server.get.sh                  # sessions, clients, status settings
#   tmux.server.get.sh --sweeps 40      # also sample the server's children
#   tmux.server.get.sh --secs 10        # also measure WHY the server burns cpu
#
# options:
#   --sweeps N   sample the server's direct children N times, 50ms apart,
#                and group them by argv (default 0 = no sample)
#   --secs N     over an N-second window, measure the server's own cpu and
#                split it into its two loads (default 0 = no window):
#                  - IN:  tmux client commands that connect to the socket,
#                         grouped by subcommand and by the caller that ran them
#                  - OUT: windows that drew output in the window, times the
#                         clients attached to them — each draw is per client
#   --help, -h   show usage and exit
#
# guarantee:
#   - read-only; asks the server, signals none, sets no option
#   - exit 0 = answered; 2 = bad args or no tmux server
######################################################################
set -uo pipefail

SWEEPS=0
SECS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)  shift 2 ;;   # rhx passes its own name through; not ours to read
    --sweeps) SWEEPS="$2"; shift 2 ;;
    --secs)   SECS="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ "$SWEEPS" =~ ^[0-9]+$ ]] || { echo "✋ ConstraintError: --sweeps must be a whole number" >&2; exit 2; }
[[ "$SECS" =~ ^[0-9]+$ ]] || { echo "✋ ConstraintError: --secs must be a whole number" >&2; exit 2; }

SERVER_PID="$(tmux display-message -p '#{pid}' 2>/dev/null)"
if [[ -z "$SERVER_PID" ]]; then
  echo "✋ ConstraintError: no tmux server answers on the default socket" >&2
  exit 2
fi

opt() { tmux show-options -gv "$1" 2>/dev/null; }

echo "🐢 heres the tmux server"
echo ""
echo "🐚 tmux.server.get"
echo "   ├─ server pid: $SERVER_PID"
echo "   ├─ sessions:   $(tmux list-sessions 2>/dev/null | wc -l)"
echo "   ├─ clients:    $(tmux list-clients 2>/dev/null | wc -l)"
echo "   ├─ panes:      $(tmux list-panes -a 2>/dev/null | wc -l)"

# scrollback held in RAM, summed across every pane — the memory the history-limit buys
read -r HIST_LINES HIST_BYTES HIST_MAX < <(
  tmux list-panes -a -F '#{history_size} #{history_bytes}' 2>/dev/null \
    | awk '{l+=$1; b+=$2; if ($1>m) m=$1} END {printf "%d %d %d\n", l, b, m}'
)
echo "   ├─ scrollback (in RAM, all panes)"
echo "   │  ├─ history-limit: $(opt history-limit) lines per pane"
echo "   │  ├─ held:          ${HIST_LINES} lines, $(( HIST_BYTES / 1048576 ))M of cell data"
echo "   │  └─ fullest pane:  ${HIST_MAX} lines"
echo "   ├─ status"
echo "   │  ├─ status:          $(opt status)"
echo "   │  ├─ status-interval: $(opt status-interval)s"
echo "   │  ├─ default-shell:   $(opt default-shell)"
echo "   │  ├─ status-left:     $(opt status-left | head -c 200)"
echo "   │  └─ status-right:    $(opt status-right | head -c 200)"

# sessions that override the global status settings — each override is its own clock
echo "   ├─ per-session overrides (status-interval / status-right)"
overrides=0
while read -r s; do
  iv="$(tmux show-options -t "$s" -v status-interval 2>/dev/null)"
  sr="$(tmux show-options -t "$s" -v status-right 2>/dev/null)"
  if [[ -n "$iv" || -n "$sr" ]]; then
    echo "   │  ├─ $s  interval=${iv:-·}  right=$(printf '%s' "${sr:-·}" | head -c 120)"
    overrides=$((overrides + 1))
  fi
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
(( overrides == 0 )) && echo "   │  └─ (none)"

if (( SECS > 0 )); then
  # the caller of a tmux client: the .sh it runs, never the interpreter that runs it
  caller_of() {
    local argv word
    argv="$(tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null)"
    for word in $argv; do
      [[ "$word" == *.sh ]] && { basename "$word"; return; }
    done
    printf '%s' "${argv:0:60}"
  }

  # the clients alive at the start are attached terminals, not requests
  declare -A LIVE=()
  for pid in $(pgrep -f '^tmux' 2>/dev/null); do LIVE[$pid]=1; done

  read_cpu() { awk '{print $14 + $15}' "/proc/$SERVER_PID/stat" 2>/dev/null; }
  TICK="$(getconf CLK_TCK)"
  T0="$(date +%s)"
  CPU0="$(read_cpu)"

  # sweep for newborn tmux clients; group by subcommand and by caller
  declare -A NEWBORN=()
  declare -A BY_CMD=()
  declare -A BY_CALLER=()
  END=$(( T0 + SECS ))
  while (( $(date +%s) < END )); do
    for pid in $(pgrep -f '^tmux' 2>/dev/null); do
      [[ -n "${LIVE[$pid]:-}${NEWBORN[$pid]:-}" || "$pid" == "$SERVER_PID" ]] && continue
      argv="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
      [[ -z "$argv" ]] && continue
      NEWBORN[$pid]=1
      sub="$(awk '{for (i = 2; i <= NF; i++) if ($i !~ /^-/) {print $i; exit}}' <<<"$argv")"
      BY_CMD[${sub:-?}]=$(( ${BY_CMD[${sub:-?}]:-0} + 1 ))
      ppid="$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null)"
      who="$(caller_of "${ppid:-0}")"
      BY_CALLER[${who:-?}]=$(( ${BY_CALLER[${who:-?}]:-0} + 1 ))
    done
    sleep 0.05
  done
  CPU1="$(read_cpu)"
  PCT=$(( (CPU1 - CPU0) * 100 / TICK / SECS ))

  # OUT: windows that drew output in the window, times the clients that view them
  declare -A VIEWERS=()
  while read -r win; do
    VIEWERS[$win]=$(( ${VIEWERS[$win]:-0} + 1 ))
  done < <(tmux list-clients -F '#{session_name}:#{window_index}' 2>/dev/null)
  DREW=0; DRAWS=0; UNSEEN=0
  declare -A FANOUT=()
  while read -r act win; do
    (( act >= T0 )) || continue
    DREW=$(( DREW + 1 ))
    n="${VIEWERS[$win]:-0}"
    (( n == 0 )) && UNSEEN=$(( UNSEEN + 1 ))
    DRAWS=$(( DRAWS + n ))
    (( n > 1 )) && FANOUT[$win]=$n
  done < <(tmux list-windows -a -F '#{window_activity} #{session_name}:#{window_index}' 2>/dev/null)

  echo "   ├─ load, over ${SECS}s"
  echo "   │  ├─ server cpu: ${PCT}% of one core (single-threaded, so 100% is its ceiling)"
  echo "   │  ├─ IN:  ${#NEWBORN[@]} tmux client commands seen (a 50ms sweep; a lower bound)"
  echo "   │  │  ├─ by subcommand"
  for k in "${!BY_CMD[@]}"; do printf '%5s  %s\n' "${BY_CMD[$k]}" "$k"; done \
    | sort -rn | head -8 | sed 's/^/   │  │  │  ├─ /'
  echo "   │  │  └─ by caller"
  for k in "${!BY_CALLER[@]}"; do printf '%5s  %s\n' "${BY_CALLER[$k]}" "$k"; done \
    | sort -rn | head -8 | sed 's/^/   │  │     ├─ /'
  echo "   │  └─ OUT: ${DREW} windows drew output; ${UNSEEN} of them viewed by no client"
  echo "   │     ├─ client redraws owed: ${DRAWS} (each window × the clients that view it)"
  echo "   │     └─ windows drawn to 2+ clients"
  for k in "${!FANOUT[@]}"; do printf '%5s  %s\n' "${FANOUT[$k]}" "$k"; done \
    | sort -rn | head -8 | sed 's/^/   │        ├─ /'
fi

if (( SWEEPS == 0 )); then
  echo "   └─ 🪄 to see what it forks:  rhx tmux.server.get --sweeps 40"
  exit 0
fi

# sample the server's direct children; group by argv, count distinct pids
echo "   └─ children of $SERVER_PID, over $SWEEPS sweeps (distinct pids per argv)"
declare -A SEEN=()
declare -A COUNT=()
for (( i = 0; i < SWEEPS; i++ )); do
  for kid in $(pgrep -P "$SERVER_PID" 2>/dev/null); do
    [[ -n "${SEEN[$kid]:-}" ]] && continue
    argv="$(tr '\0' ' ' < "/proc/$kid/cmdline" 2>/dev/null | head -c 160)"
    [[ -z "$argv" ]] && continue
    SEEN[$kid]=1
    COUNT[$argv]=$(( ${COUNT[$argv]:-0} + 1 ))
  done
  sleep 0.05
done
for argv in "${!COUNT[@]}"; do
  printf '%5s  %s\n' "${COUNT[$argv]}" "$argv"
done | sort -rn | head -15 | sed 's/^/      ├─ /'
echo "      └─ (a pane's own shell shows 1; a clocked job shows many)"
exit 0
