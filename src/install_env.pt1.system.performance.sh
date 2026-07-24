#!/usr/bin/env bash
######################################################################
# pt1c: system performance
# sysctl (inotify, swappiness), swapfile, earlyoom, runaway monitor
######################################################################

configure_sysctl() {
  #########################
  ## bump max files watched
  ## per https://stackoverflow.com/a/32600959/3068233
  #########################
  if ! grep -q '^fs.inotify.max_user_watches=' /etc/sysctl.conf; then
    echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
  fi

  #############################
  ## set swappiness — prefer RAM over swap
  ## ref: https://wiki.debian.org/swappiness
  #############################
  if ! grep -q '^vm.swappiness=' /etc/sysctl.conf; then
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  fi

  sudo sysctl -p
}

configure_swapfile() {
  #############################
  ## add swapfile for overflow (complements zram)
  ##
  ## why: zram compresses cold pages in RAM (fast, ~16gb default)
  ##      when zram fills, overflow goes to disk swap
  ##      more disk swap = more headroom for cold pages
  ##
  ## hierarchy: RAM -> zram (compressed RAM) -> disk swap (SSD)
  ##
  ## sizing: used as a brain-cli idlelot. those things hog memory
  ##         and we often keep them idle, so this lets them spill
  ##         over and give way to priorities without need to close them
  #############################
  local swapfile="/swapfile"
  local size="72G"

  # skip if swapfile already exists and is active
  if swapon --show | grep -q "$swapfile"; then
    echo "• swapfile already active; skipped"
    return 0
  fi

  # create swapfile if it doesn't exist
  if [[ ! -f "$swapfile" ]]; then
    echo "• create ${size} swapfile..."
    sudo fallocate -l "$size" "$swapfile"
    sudo chmod 600 "$swapfile"
    sudo mkswap "$swapfile"
  fi

  # activate swapfile
  sudo swapon "$swapfile"

  # add to fstab if not already present
  if ! grep -q "$swapfile" /etc/fstab; then
    echo "$swapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    echo "• swapfile added to /etc/fstab"
  fi

  echo "• swapfile configured: $size"
}

install_earlyoom() {
  #############################
  ## earlyoom — early OOM killer
  ##
  ## why: linux default OOM killer activates too late (system already frozen)
  ##      earlyoom kills memory hogs earlier, keeping system responsive
  ##
  ## ref: https://github.com/rfjakob/earlyoom
  #############################
  if command -v earlyoom &>/dev/null; then
    echo "• earlyoom already installed; skipped"
    return 0
  fi

  sudo apt install -y earlyoom
  sudo systemctl enable --now earlyoom
  echo "• earlyoom installed and enabled"
}

install_runaway_monitor() {
  #############################
  ## runaway process monitor
  ##
  ## what: checks CPU load + memory every 2 min
  ##       sends desktop notification if thresholds exceeded
  ##       includes command to kill offenders
  ##
  ## why: catch nvim/node/etc spinning out before system grinds to halt
  ##
  ## compat: works on GNOME (X11) and COSMIC (Wayland)
  #############################

  # ensure dependencies
  if ! command -v bc &>/dev/null; then
    sudo apt install -y bc
  fi

  local bin_path="$HOME/.local/bin/machine_resource_procs_monitor"
  local service_path="$HOME/.config/systemd/user/runaway_monitor.service"
  local timer_path="$HOME/.config/systemd/user/runaway_monitor.timer"

  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.config/systemd/user"

  # create the monitor executable (calls machine_resource_procs_find_runaway and machine_resource_procs_find_orphan)
  cat > "$bin_path" << 'MONITOR'
#!/bin/bash
#############################
# machine_resource_procs_monitor (monitor daemon)
# calls machine_resource_procs_find_runaway every 2 min, machine_resource_procs_find_orphan every 1 hr
#############################

STATE_DIR="$HOME/.local/state"
COOLDOWN_FILE="$STATE_DIR/runaway_monitor.cooldown"
COOLDOWN_SECONDS=600  # 10 minutes between resource alerts
ORPHAN_RUN_COUNTER="$STATE_DIR/runaway_monitor.orphan-counter"
ORPHAN_CHECK_INTERVAL=30  # check orphans every 30 runs (1 hour at 2-min intervals)

mkdir -p "$STATE_DIR"

# import graphical session env for notify-send (works on both X11 and Wayland)
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
  eval "$(systemctl --user show-environment | grep -E '^(DISPLAY|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS)=')"
fi

#############################
# runaway check (every run)
#############################
if command -v machine_resource_procs_find_runaway &>/dev/null; then
  RUNAWAY_JSON=$(machine_resource_procs_find_runaway --json 2>/dev/null)
  LOAD_HIGH=$(echo "$RUNAWAY_JSON" | grep -o '"load_high": [0-9]*' | grep -o '[0-9]*')
  MEM_LOW=$(echo "$RUNAWAY_JSON" | grep -o '"mem_low": [0-9]*' | grep -o '[0-9]*')

  if [[ "$LOAD_HIGH" == "1" || "$MEM_LOW" == "1" ]]; then
    # check cooldown
    SHOULD_ALERT=1
    if [[ -f "$COOLDOWN_FILE" ]]; then
      last_alert=$(cat "$COOLDOWN_FILE" 2>/dev/null)
      if [[ "$last_alert" =~ ^[0-9]+$ ]]; then
        now=$(date +%s)
        if (( now - last_alert < COOLDOWN_SECONDS )); then
          SHOULD_ALERT=0
        fi
      fi
    fi

    if [[ $SHOULD_ALERT -eq 1 ]]; then
      RUNAWAY_MSG=$(machine_resource_procs_find_runaway 2>/dev/null)
      notify-send -u critical "🔥 System Resource Alert" "$RUNAWAY_MSG"
      date +%s > "$COOLDOWN_FILE"
      logger -t runaway_monitor "ALERT: $RUNAWAY_JSON"
    fi
  else
    # clear cooldown when system recovers
    rm -f "$COOLDOWN_FILE"
  fi
fi

#############################
# orphan check (1/hr)
#############################
ORPHAN_COUNT=$(cat "$ORPHAN_RUN_COUNTER" 2>/dev/null || echo 0)
if ! [[ "$ORPHAN_COUNT" =~ ^[0-9]+$ ]]; then
  ORPHAN_COUNT=0
fi
ORPHAN_COUNT=$((ORPHAN_COUNT + 1))

if (( ORPHAN_COUNT >= ORPHAN_CHECK_INTERVAL )); then
  echo 0 > "$ORPHAN_RUN_COUNTER"

  if command -v machine_resource_procs_find_orphan &>/dev/null; then
    ORPHAN_OUTPUT=$(machine_resource_procs_find_orphan 2>/dev/null)
    # check if orphans found (output contains 🪲 prey emoji)
    if [[ "$ORPHAN_OUTPUT" == *"🪲"* ]]; then
      notify-send -u normal "🐈 Orphan Caught" "$ORPHAN_OUTPUT"
      logger -t runaway_monitor "ORPHAN_ALERT: found orphan processes"
    fi
  fi
else
  echo "$ORPHAN_COUNT" > "$ORPHAN_RUN_COUNTER"
fi
MONITOR

  chmod +x "$bin_path"

  # create systemd service
  cat > "$service_path" << 'SERVICE'
[Unit]
Description=Check for runaway processes

[Service]
Type=oneshot
ExecStart=%h/.local/bin/machine_resource_procs_monitor
StandardOutput=journal
StandardError=journal
SERVICE

  # create systemd timer (every 2 min, 5 min delay after boot)
  cat > "$timer_path" << 'TIMER'
[Unit]
Description=Run runaway process check every 2 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
TIMER

  # enable timer
  systemctl --user daemon-reload
  systemctl --user enable --now runaway_monitor.timer

  # verify installation
  if ! command -v bc &>/dev/null; then
    echo "✗ runaway_monitor install failed: bc not available" >&2
    exit 1
  fi
  if ! command -v notify-send &>/dev/null; then
    echo "✗ runaway_monitor install failed: notify-send not available" >&2
    exit 1
  fi
  if ! command -v logger &>/dev/null; then
    echo "✗ runaway_monitor install failed: logger not available" >&2
    exit 1
  fi
  if ! systemctl --user is-enabled runaway_monitor.timer &>/dev/null; then
    echo "✗ runaway_monitor install failed: timer not enabled" >&2
    exit 1
  fi

  echo "• runaway_monitor installed and enabled (checks every 2 min)"
}

install_machine_resource_procs_find_runaway() {
  #############################
  ## machine_resource_procs_find_runaway command
  ##
  ## what: finds processes with high CPU load or memory use
  ## why: detect runaway processes before system becomes unresponsive
  ## usage: machine_resource_procs_find_runaway [--json | --kill cpu | --kill mem]
  #############################

  local bin_path="$HOME/.local/bin/machine_resource_procs_find_runaway"

  mkdir -p "$HOME/.local/bin"

  cat > "$bin_path" << 'RUNAWAY_SCRIPT'
#!/bin/bash
#############################
# machine_resource_procs_find_runaway
# checks CPU load and memory, reports offenders
#############################

JSON_MODE=0
FULL_MODE=0
KILL_MODE=""
KILL_TYPE=""
MIN_PROCS=3

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=1; shift ;;
    --full) FULL_MODE=1; shift ;;
    --min)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        MIN_PROCS="$2"
        shift 2
      else
        echo "Usage: --min requires a number" >&2
        exit 1
      fi
      ;;
    --kill)
      if [[ -n "$2" && "$2" != --* ]]; then
        KILL_MODE="$2"
        shift 2
        # check for optional type (cpu|mem) after prefix
        if [[ -n "$1" && "$1" != --* && ("$1" == "cpu" || "$1" == "mem") ]]; then
          KILL_TYPE="$1"
          shift
        fi
      else
        echo "Usage: machine_resource_procs_find_runaway [--full | --json | --min N | --kill cpu | --kill mem | --kill <prefix> [cpu|mem]]" >&2
        exit 1
      fi
      ;;
    *)
      echo "Usage: machine_resource_procs_find_runaway [--full | --json | --min N | --kill cpu | --kill mem | --kill <prefix> [cpu|mem]]" >&2
      exit 1
      ;;
  esac
done

MAX_ROW=$((MIN_PROCS + 1))

LOAD=$(awk '{print $1}' /proc/loadavg)
CORES=$(nproc)
LOAD_THRESHOLD=$(echo "$CORES * 1.5" | bc)

MEM_AVAIL_PCT=$(awk '/MemAvailable/{a=$2} /MemTotal/{t=$2} END{printf "%.0f", (a/t)*100}' /proc/meminfo)
MEM_THRESHOLD=15

# swap info
SWAP_INFO=$(awk '/SwapTotal/{t=$2} /SwapFree/{f=$2} END{printf "%d %d", t, f}' /proc/meminfo)
SWAP_TOTAL_KB=$(echo "$SWAP_INFO" | awk '{print $1}')
SWAP_FREE_KB=$(echo "$SWAP_INFO" | awk '{print $2}')
SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
if [[ "$SWAP_TOTAL_KB" -gt 0 ]]; then
  SWAP_USED_PCT=$(( (SWAP_USED_KB * 100) / SWAP_TOTAL_KB ))
  SWAP_TOTAL_GB=$(echo "scale=1; $SWAP_TOTAL_KB / 1048576" | bc)
  SWAP_USED_GB=$(echo "scale=1; $SWAP_USED_KB / 1048576" | bc)
  SWAP_FREE_GB=$(echo "scale=1; $SWAP_FREE_KB / 1048576" | bc)
else
  SWAP_USED_PCT=0
  SWAP_TOTAL_GB="0"
  SWAP_USED_GB="0"
  SWAP_FREE_GB="0"
fi

LOAD_HIGH=0
if (( $(echo "$LOAD > $LOAD_THRESHOLD" | bc -l) )); then
  LOAD_HIGH=1
fi

MEM_LOW=0
if (( MEM_AVAIL_PCT < MEM_THRESHOLD )); then
  MEM_LOW=1
fi

# cache ps output
PS_BY_CPU=$(ps aux --sort=-%cpu)
PS_BY_MEM=$(ps aux --sort=-%mem)

format_top_procs() {
  local ps_output="$1"
  local mode="$2"
  local max_row="$3"
  echo "$ps_output" | awk -v mode="$mode" -v max="$max_row" 'NR>1 && NR<=max {
    pid=$2; cpu=$3; mem=$4
    cmd_file="/proc/"pid"/comm"
    if ((getline cmd < cmd_file) > 0) { close(cmd_file) } else { cmd=$11 }
    if (mode == "cpu") {
      printf "%s (%.0f%% CPU, %.0f%% MEM, PID %s)\n", cmd, cpu, mem, pid
    } else {
      printf "%s (%.0f%% MEM, %.0f%% CPU, PID %s)\n", cmd, mem, cpu, pid
    }
  }'
}

extract_pids() {
  local limit="${2:-4}"  # default top 3 (NR>1 means skip header)
  echo "$1" | awk -v limit="$limit" 'NR>1 && NR<=limit {print $2}' | tr '\n' ' '
}

TOP_CPU=$(format_top_procs "$PS_BY_CPU" "cpu" "$MAX_ROW")
TOP_MEM=$(format_top_procs "$PS_BY_MEM" "mem" "$MAX_ROW")
CPU_PIDS=$(extract_pids "$PS_BY_CPU" "$MAX_ROW")
MEM_PIDS=$(extract_pids "$PS_BY_MEM" 11)  # top 10 for memory

if [[ $JSON_MODE -eq 1 ]]; then
  echo "{"
  echo "  \"load\": $LOAD,"
  echo "  \"load_threshold\": $LOAD_THRESHOLD,"
  echo "  \"load_high\": $LOAD_HIGH,"
  echo "  \"mem_avail_pct\": $MEM_AVAIL_PCT,"
  echo "  \"mem_threshold\": $MEM_THRESHOLD,"
  echo "  \"mem_low\": $MEM_LOW,"
  echo "  \"cpu_pids\": \"$CPU_PIDS\","
  echo "  \"mem_pids\": \"$MEM_PIDS\""
  echo "}"
  exit 0
fi

echo "🐈 lets prowl..."
echo "└─🌕 runaway"

print_proc_details() {
  local pid="$1"
  local cpu="$2"
  local mem="$3"
  local prefix="$4"

  # dead-on-read: the process exited between the ps snapshot and this re-read.
  # its /proc is already gone, so its ps %CPU is stale and its start time is
  # unreadable. report it as exited rather than fake an age from system uptime.
  if [[ ! -r /proc/$pid/stat ]]; then
    echo "${prefix}├─ 💨 [exited] (was ${cpu}% CPU, ${mem}% MEM, PID $pid — gone before re-read)"
    return
  fi

  local comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
  local cwd=$(readlink /proc/$pid/cwd 2>/dev/null | sed "s|^$HOME|~|" || echo "?")
  local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | cut -c1-60 || echo "?")

  # calculate elapsed time from process start.
  # only trust a real start time; if it is absent the process raced out from
  # under us, so show "?" rather than infer uptime as the age.
  local clk_tck=$(getconf CLK_TCK)
  local uptime_sec=$(awk '{print int($1)}' /proc/uptime)
  local starttime=$(awk '{print $22}' /proc/$pid/stat 2>/dev/null)
  local elapsed_str="?"
  if [[ -n "$starttime" && "$starttime" -gt 0 ]]; then
    local start_sec=$((starttime / clk_tck))
    local elapsed_sec=$((uptime_sec - start_sec))
    local elapsed_min=$((elapsed_sec / 60))
    local elapsed_hr=$((elapsed_min / 60))
    if [[ $elapsed_hr -gt 0 ]]; then
      elapsed_str="${elapsed_hr}h$((elapsed_min % 60))m"
    elif [[ $elapsed_min -gt 0 ]]; then
      elapsed_str="${elapsed_min}m"
    else
      elapsed_str="${elapsed_sec}s"
    fi
  fi

  # 🐛 if process is a hog (>50% CPU or >10% MEM), 🫧 otherwise
  local emoji="🫧"
  if [[ ${cpu%.*} -gt 50 ]] || [[ ${mem%.*} -gt 10 ]]; then
    emoji="🐛"
  fi

  echo "${prefix}├─ $emoji $comm (${cpu}% CPU, ${mem}% MEM, ${elapsed_str}, PID $pid)"
  echo "${prefix}│     ├─ cwd: $cwd"
  echo "${prefix}│     └─ cmd: $cmdline"
}

# always show top CPU hogs so user can decide
if [[ $LOAD_HIGH -eq 1 ]]; then
  echo "  ├─🕯️ high load: $LOAD/$CORES (threshold: $LOAD_THRESHOLD)"
else
  echo "  ├─✨ load: $LOAD/$CORES"
fi
echo "$PS_BY_CPU" | awk -v max="$MAX_ROW" 'NR>1 && NR<=max {printf "%s %s %s\n", $2, $3, $4}' | while read pid cpu mem; do
  print_proc_details "$pid" "${cpu%.*}" "${mem%.*}" "  │    "
done
echo "  │    └─ 🪄 kill -9 $CPU_PIDS"
if [[ $MEM_LOW -eq 1 || $FULL_MODE -eq 1 ]]; then
  # get memory stats for display
  MEM_TOTAL_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  MEM_AVAIL_KB=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
  MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
  MEM_TOTAL_GB=$(echo "scale=1; $MEM_TOTAL_KB / 1048576" | bc)
  MEM_USED_GB=$(echo "scale=1; $MEM_USED_KB / 1048576" | bc)
  MEM_AVAIL_GB=$(echo "scale=1; $MEM_AVAIL_KB / 1048576" | bc)
  MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))

  if [[ $MEM_LOW -eq 1 ]]; then
    echo "  ├─🕯️ low memory"
  else
    echo "  ├─✨ memory"
  fi
  echo "  │     ram:  ${MEM_USED_GB}G / ${MEM_TOTAL_GB}G used (${MEM_AVAIL_GB}G free, ${MEM_AVAIL_PCT}% avail)"
  echo "  │     swap: ${SWAP_USED_GB}G / ${SWAP_TOTAL_GB}G used (${SWAP_FREE_GB}G free)"
  echo "  │"
  echo "  │    📊 RAM by process (aggregated):"
  # aggregate RSS by process name with count, sort by size, show top 8
  ps aux | awk 'NR>1 {
    pid=$2; rss=$6
    cmd_file="/proc/"pid"/comm"
    if ((getline cmd < cmd_file) > 0) { close(cmd_file) } else { cmd=$11 }
    mem[cmd] += rss
    cnt[cmd]++
  }
  END {
    for (name in mem) print mem[name], cnt[name], name
  }' | sort -rn | head -8 | awk -v total_mb="$MEM_TOTAL_MB" '{
    kb=$1; count=$2; name=$3
    mb = kb / 1024
    pct = (kb / 1024 / total_mb) * 100
    if (mb >= 1024) {
      printf "  │       ├─ %5.1fG (%4.1f%%)  %s  ×%d\n", mb/1024, pct, name, count
    } else {
      printf "  │       ├─ %5.0fM (%4.1f%%)  %s  ×%d\n", mb, pct, name, count
    }
  }'
  echo "  │"
  echo "  │    📊 SWAP by process (aggregated):"
  # aggregate VmSwap by process name with count
  for pid_dir in /proc/[0-9]*; do
    p="${pid_dir##*/}"
    val=$(awk '/VmSwap/{print $2}' "$pid_dir/status" 2>/dev/null)
    if [[ -n "$val" && "$val" -gt 0 ]]; then
      name=$(cat "$pid_dir/comm" 2>/dev/null || echo "?")
      echo "$val $name"
    fi
  done | awk '{swap[$2]+=$1; cnt[$2]++} END {for(n in swap) print swap[n], cnt[n], n}' | sort -rn | head -8 | awk '{
    kb=$1; count=$2; name=$3
    mb = kb / 1024
    if (mb >= 1024) {
      printf "  │       ├─ %5.1fG  %s  ×%d\n", mb/1024, name, count
    } else {
      printf "  │       ├─ %5.0fM  %s  ×%d\n", mb, name, count
    }
  }'
  echo "  │"
  echo "  │    🐛 top 10 processes (RAM):"
  echo "$PS_BY_MEM" | awk 'NR>1 && NR<=11 {printf "%s %s %s\n", $2, $3, $4}' | while read pid cpu mem; do
    print_proc_details "$pid" "${cpu%.*}" "${mem%.*}" "  │    "
  done
  echo "  │    └─ 🪄 kill -9 $MEM_PIDS"
fi

# handle --kill mode
if [[ -n "$KILL_MODE" ]]; then
  echo ""
  if [[ "$KILL_MODE" == "cpu" ]]; then
    echo "Kill top CPU processes: $CPU_PIDS"
    kill -9 $CPU_PIDS 2>/dev/null
  elif [[ "$KILL_MODE" == "mem" ]]; then
    echo "Kill top MEM processes: $MEM_PIDS"
    kill -9 $MEM_PIDS 2>/dev/null
  else
    # kill by prefix, optionally filtered to cpu or mem list
    if [[ "$KILL_TYPE" == "cpu" ]]; then
      # filter prefix within CPU list only
      FILTERED_PIDS=""
      for pid in $CPU_PIDS; do
        comm=$(cat /proc/$pid/comm 2>/dev/null || echo "")
        if [[ "$comm" == *"$KILL_MODE"* ]]; then
          FILTERED_PIDS+="$pid "
        fi
      done
      if [[ -z "$FILTERED_PIDS" ]]; then
        echo "No CPU processes found with prefix: $KILL_MODE"
      else
        echo "Kill CPU processes with prefix '$KILL_MODE': $FILTERED_PIDS"
        kill -9 $FILTERED_PIDS 2>/dev/null
      fi
    elif [[ "$KILL_TYPE" == "mem" ]]; then
      # filter prefix within MEM list only
      FILTERED_PIDS=""
      for pid in $MEM_PIDS; do
        comm=$(cat /proc/$pid/comm 2>/dev/null || echo "")
        if [[ "$comm" == *"$KILL_MODE"* ]]; then
          FILTERED_PIDS+="$pid "
        fi
      done
      if [[ -z "$FILTERED_PIDS" ]]; then
        echo "No MEM processes found with prefix: $KILL_MODE"
      else
        echo "Kill MEM processes with prefix '$KILL_MODE': $FILTERED_PIDS"
        kill -9 $FILTERED_PIDS 2>/dev/null
      fi
    else
      # kill all with prefix (no type filter)
      PREFIX_PIDS=$(ps aux | awk -v prefix="$KILL_MODE" '$11 ~ prefix || $0 ~ prefix {print $2}' | grep -v "^$$\$" | head -10 | tr '\n' ' ')
      if [[ -z "$PREFIX_PIDS" ]]; then
        echo "No processes found with prefix: $KILL_MODE"
      else
        echo "Kill processes with prefix '$KILL_MODE': $PREFIX_PIDS"
        kill -9 $PREFIX_PIDS 2>/dev/null
      fi
    fi
  fi
  echo "Done."
fi
RUNAWAY_SCRIPT

  chmod +x "$bin_path"
  echo "• machine_resource_procs_find_runaway installed ($bin_path)"
}

install_machine_resource_procs_find_spinner() {
  #############################
  ## machine_resource_procs_find_spinner command
  ##
  ## what: finds processes with sustained high CPU usage
  ## why: detect processes that have been spinning for 30+ min
  ## usage: machine_resource_procs_find_spinner [--kill [<prefix>]]
  #############################

  local bin_path="$HOME/.local/bin/machine_resource_procs_find_spinner"

  mkdir -p "$HOME/.local/bin"

  cat > "$bin_path" << 'SPINNER_SCRIPT'
#!/bin/bash
#############################
# machine_resource_procs_find_spinner
# finds processes with CPU time / elapsed time ratio > 0.5
# that have been running for 30+ minutes
#############################

KILL_MODE=""
MIN_ELAPSED=1800  # 30 minutes in seconds
MIN_RATIO=50      # 50% CPU ratio threshold

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kill)
      KILL_MODE="all"
      if [[ -n "$2" && "$2" != --* ]]; then
        KILL_MODE="$2"
        shift
      fi
      shift
      ;;
    --min-minutes)
      MIN_ELAPSED=$(( $2 * 60 ))
      shift 2
      ;;
    --min-ratio)
      MIN_RATIO="$2"
      shift 2
      ;;
    *)
      echo "Usage: machine_resource_procs_find_spinner [--kill [<prefix>]] [--min-minutes N] [--min-ratio N]" >&2
      exit 1
      ;;
  esac
done

SPINNER_PIDS=""
SPINNER_INFO=""

# get user processes with elapsed and cpu time
while read -r pid etimes cputimes comm; do
  [[ -z "$pid" ]] && continue
  [[ "$etimes" -lt "$MIN_ELAPSED" ]] && continue

  # calculate ratio (percentage)
  if [[ "$etimes" -gt 0 ]]; then
    ratio=$(( (cputimes * 100) / etimes ))
  else
    ratio=0
  fi

  if [[ "$ratio" -ge "$MIN_RATIO" ]]; then
    elapsed_min=$(( etimes / 60 ))
    cpu_min=$(( cputimes / 60 ))
    SPINNER_PIDS+="$pid "
    SPINNER_INFO+="$pid ($comm): ${ratio}% CPU over ${elapsed_min}m (${cpu_min}m CPU time)\n"
  fi
done < <(ps -u "$USER" -o pid=,etimes=,cputimes=,comm= 2>/dev/null)

if [[ -z "$SPINNER_PIDS" ]]; then
  echo "🐈 lets prowl..."
  echo "└─🌕 spinner"
  echo "  └─✨ none caught"
  exit 0
fi

echo "🐈 lets prowl..."
echo "└─🌕 spinner"
# format as tree entries
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  echo "  ├─🦎 $line"
done <<< "$(echo -e "$SPINNER_INFO")"
echo "  └─🪄 kill -9 $SPINNER_PIDS"

if [[ -n "$KILL_MODE" ]]; then
  echo ""
  if [[ "$KILL_MODE" == "all" ]]; then
    echo "Kill all spinner processes..."
    kill -9 $SPINNER_PIDS 2>/dev/null
  else
    # filter by prefix
    FILTERED_PIDS=""
    for pid in $SPINNER_PIDS; do
      comm=$(cat /proc/$pid/comm 2>/dev/null || echo "")
      if [[ "$comm" == *"$KILL_MODE"* ]]; then
        FILTERED_PIDS+="$pid "
      fi
    done
    if [[ -z "$FILTERED_PIDS" ]]; then
      echo "No spinner processes matching '$KILL_MODE'"
    else
      echo "Kill spinner processes matching '$KILL_MODE': $FILTERED_PIDS"
      kill -9 $FILTERED_PIDS 2>/dev/null
    fi
  fi
  echo "Done."
fi
SPINNER_SCRIPT

  chmod +x "$bin_path"
  echo "• machine_resource_procs_find_spinner installed ($bin_path)"
}

install_machine_resource_procs_find_orphan() {
  #############################
  ## machine_resource_procs_find_orphan command
  ##
  ## what: finds processes whose cwd was deleted
  ## why: detect abandoned processes from deleted worktrees, temp dirs, etc.
  ## usage: machine_resource_procs_find_orphan [--kill [<prefix>]]
  #############################

  local bin_path="$HOME/.local/bin/machine_resource_procs_find_orphan"

  mkdir -p "$HOME/.local/bin"

  cat > "$bin_path" << 'ORPHAN_SCRIPT'
#!/bin/bash
#############################
# machine_resource_procs_find_orphan
# finds processes whose cwd was deleted
#############################

KILL_MODE=""
if [[ "$1" == "--kill" ]]; then
  KILL_MODE="all"
  if [[ -n "$2" && "$2" != --* ]]; then
    KILL_MODE="$2"
  fi
fi

ORPHAN_PIDS=""
ORPHAN_INFO=""

for pid in $(ps -u "$USER" -o pid= 2>/dev/null); do
  # skip if we can't read the cwd (process may have exited)
  cwd=$(readlink /proc/$pid/cwd 2>/dev/null) || continue

  # check if cwd is deleted or doesn't exist
  if [[ "$cwd" == *"(deleted)"* ]] || [[ ! -d "$cwd" ]]; then
    comm=$(cat /proc/$pid/comm 2>/dev/null || echo "unknown")
    ORPHAN_PIDS+="$pid "
    ORPHAN_INFO+="$pid ($comm): $cwd\n"
  fi
done

if [[ -z "$ORPHAN_PIDS" ]]; then
  echo "🐈 lets prowl..."
  echo "└─🌕 orphan"
  echo "  └─✨ no strays"
  exit 0
fi

echo "🐈 lets prowl..."
echo "└─🌕 orphan"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  echo "  ├─🪲 $line"
done <<< "$(echo -e "$ORPHAN_INFO")"
echo "  └─🪄 kill -9 $ORPHAN_PIDS"

if [[ -n "$KILL_MODE" ]]; then
  echo ""
  if [[ "$KILL_MODE" == "all" ]]; then
    echo "Kill all orphan processes..."
    kill -9 $ORPHAN_PIDS 2>/dev/null
  else
    # filter by prefix
    FILTERED_PIDS=""
    for pid in $ORPHAN_PIDS; do
      comm=$(cat /proc/$pid/comm 2>/dev/null || echo "")
      if [[ "$comm" == *"$KILL_MODE"* ]]; then
        FILTERED_PIDS+="$pid "
      fi
    done
    if [[ -z "$FILTERED_PIDS" ]]; then
      echo "No orphan processes matching '$KILL_MODE'"
    else
      echo "Kill orphan processes matching '$KILL_MODE': $FILTERED_PIDS"
      kill -9 $FILTERED_PIDS 2>/dev/null
    fi
  fi
  echo "Done."
fi
ORPHAN_SCRIPT

  chmod +x "$bin_path"
  echo "• machine_resource_procs_find_orphan installed ($bin_path)"
}

uninstall_runaway_monitor() {
  #############################
  ## remove runaway process monitor
  #############################
  local bin_path="$HOME/.local/bin/machine_resource_procs_monitor"
  local service_path="$HOME/.config/systemd/user/runaway_monitor.service"
  local timer_path="$HOME/.config/systemd/user/runaway_monitor.timer"
  local cooldown_file="$HOME/.local/state/runaway_monitor.cooldown"

  # stop and disable timer
  systemctl --user stop runaway_monitor.timer 2>/dev/null
  systemctl --user disable runaway_monitor.timer 2>/dev/null

  # remove files
  rm -f "$bin_path" "$service_path" "$timer_path" "$cooldown_file"

  # reload systemd
  systemctl --user daemon-reload

  echo "• runaway_monitor uninstalled"
}

install_machine_resource_observe() {
  #############################
  ## machine_resource_observe command
  ##
  ## what: shows system resource snapshot
  ## why: quick overview to spot issues diagnose might miss
  ## usage: machine_resource_observe
  #############################

  local bin_path="$HOME/.local/bin/machine_resource_observe"

  mkdir -p "$HOME/.local/bin"

  cat > "$bin_path" << 'OBSERVE_SCRIPT'
#!/bin/bash
#############################
# machine_resource_observe
# system resource snapshot
#############################

echo ""
echo "🐈 lets observe..."

# system stats
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
LOAD_1=$(echo $LOAD | awk '{print $1}')
LOAD_5=$(echo $LOAD | awk '{print $2}')
LOAD_15=$(echo $LOAD | awk '{print $3}')
CORES=$(nproc)
MEM_INFO=$(free -h | awk '/^Mem:/ {print $2, $3, $4, $7}')
MEM_TOTAL=$(echo $MEM_INFO | awk '{print $1}')
MEM_USED=$(echo $MEM_INFO | awk '{print $2}')
MEM_FREE=$(echo $MEM_INFO | awk '{print $3}')
MEM_AVAIL=$(echo $MEM_INFO | awk '{print $4}')
SWAP_INFO=$(free -h | awk '/^Swap:/ {print $2, $3, $4}')
SWAP_TOTAL=$(echo $SWAP_INFO | awk '{print $1}')
SWAP_USED=$(echo $SWAP_INFO | awk '{print $2}')
SWAP_FREE=$(echo $SWAP_INFO | awk '{print $3}')

echo "   │"
echo "   ├─ 🌕 system"
echo "   │     ├─ load: $LOAD_1 / $LOAD_5 / $LOAD_15 (1m / 5m / 15m)"
echo "   │     ├─ cores: $CORES"
echo "   │     ├─ mem: $MEM_USED used / $MEM_TOTAL total (avail: $MEM_AVAIL)"
echo "   │     └─ swap: $SWAP_USED used / $SWAP_TOTAL total"

# top cpu (5 procs)
echo "   │"
echo "   ├─ 🌕 top cpu"
ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {
  pid=$2; cpu=$3; mem=$4
  cmd_file="/proc/"pid"/comm"
  if ((getline cmd < cmd_file) > 0) { close(cmd_file) } else { cmd=$11 }
  printf "   │     ├─ 🐛 %s (%.0f%% CPU, %.0f%% MEM, PID %s)\n", cmd, cpu, mem, pid
}'

# top mem (5 procs)
echo "   │"
echo "   ├─ 🌕 top mem"
ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {
  pid=$2; cpu=$3; mem=$4; rss=$6
  cmd_file="/proc/"pid"/comm"
  if ((getline cmd < cmd_file) > 0) { close(cmd_file) } else { cmd=$11 }
  # convert RSS from KB to human readable
  if (rss >= 1048576) { rss_h = sprintf("%.1fG", rss/1048576) }
  else if (rss >= 1024) { rss_h = sprintf("%.0fM", rss/1024) }
  else { rss_h = sprintf("%dK", rss) }
  printf "   │     ├─ 🐛 %s (%s, %.0f%% MEM, PID %s)\n", cmd, rss_h, mem, pid
}'

# io wait
IOWAIT=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}' | tr -d '%,wa')
if [[ -n "$IOWAIT" ]]; then
  echo "   │"
  echo "   └─ 🌕 io"
  echo "         └─ iowait: ${IOWAIT}%"
else
  echo "   │"
  echo "   └─ 🌕 io"
  echo "         └─ iowait: n/a"
fi

echo ""
OBSERVE_SCRIPT

  chmod +x "$bin_path"
  echo "• machine_resource_observe installed ($bin_path)"
}

install_tmpfiles_cleanup() {
  #############################
  ## tmpfiles cleanup timer
  ##
  ## what: prunes /tmp files older than 3 days
  ##
  ## why: systemd-tmpfiles-setup.service blocks boot for 4+ min on LUKS
  ##      if /tmp has accumulated many files between monthly reboots.
  ##      daily cleanup keeps /tmp small so boot is fast.
  ##
  ## ref: https://github.com/pop-os/pop/issues/1048
  #############################
  local service_path="/etc/systemd/system/tmp-cleanup.service"
  local timer_path="/etc/systemd/system/tmp-cleanup.timer"

  if [[ -f "$timer_path" ]]; then
    echo "• tmp cleanup timer already installed; skipped"
    return 0
  fi

  # create service
  sudo tee "$service_path" > /dev/null << 'SERVICE'
[Unit]
Description=Cleanup /tmp files older than 3 days

[Service]
Type=oneshot
ExecStart=/usr/bin/find /tmp -mindepth 1 -mtime +3 -delete
SERVICE

  # create timer (daily at 3am, Persistent=true catches missed runs on next boot)
  sudo tee "$timer_path" > /dev/null << 'TIMER'
[Unit]
Description=Daily cleanup of /tmp

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
TIMER

  sudo systemctl daemon-reload
  sudo systemctl enable --now tmp-cleanup.timer

  echo "• tmp cleanup timer installed (daily at 3am, deletes files >3 days old)"
}

install_machine_usage_snapshot() {
  local bin_path="$HOME/.local/bin/machine_usage_snapshot"
  mkdir -p "$(dirname "$bin_path")"

  cat > "$bin_path" << 'SNAPSHOT_SCRIPT'
#!/usr/bin/env bash
######################################################################
# machine_usage_snapshot — capture comprehensive system state for lag diagnosis
#
# usage:
#   machine_usage_snapshot              # snapshot to ~/.cache/machine.usage.snapshots/
#   machine_usage_snapshot --stdout     # print to stdout instead of file
#   machine_usage_snapshot --dir /path  # custom output directory
#
# captures:
#   - timestamp, hostname, kernel
#   - load average (1, 5, 15 min) vs cores
#   - cpu usage breakdown (user, system, iowait, idle)
#   - memory stats (total, avail, used, cached, buffers, swap)
#   - top 15 cpu processes with full details
#   - top 15 mem processes with full details
#   - d-state processes (blocked on I/O)
#   - zombie processes
#   - disk I/O stats
#   - file descriptor usage
#   - network connection counts
#   - recent kernel messages (dmesg)
#   - temperatures (if sensors available)
######################################################################

set -euo pipefail

SNAPSHOT_DIR="$HOME/.cache/machine.usage.snapshots"
STDOUT_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stdout)
      STDOUT_MODE=1
      shift
      ;;
    --dir)
      SNAPSHOT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Usage: machine_usage_snapshot [--stdout] [--dir /path]" >&2
      exit 1
      ;;
  esac
done

# timestamp for filename and content
TS=$(date '+%Y-%m-%d_%H-%M-%S')
TS_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')

# output destination
if [[ $STDOUT_MODE -eq 1 ]]; then
  exec 3>&1
else
  mkdir -p "$SNAPSHOT_DIR"
  OUTFILE="$SNAPSHOT_DIR/snapshot.$TS.txt"
  exec 3>"$OUTFILE"
fi

emit() {
  echo "$@" >&3
}

emit "╔══════════════════════════════════════════════════════════════════╗"
emit "║  MACHINE USAGE SNAPSHOT                                          ║"
emit "║  $TS_HUMAN"
emit "╚══════════════════════════════════════════════════════════════════╝"
emit ""

# --- system info ---
emit "┌─ SYSTEM ────────────────────────────────────────────────────────┐"
emit "│ hostname: $(hostname)"
emit "│ kernel:   $(uname -r)"
emit "│ uptime:   $(uptime -p)"
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- load average ---
CORES=$(nproc)
read -r LOAD1 LOAD5 LOAD15 _ < /proc/loadavg
emit "┌─ LOAD AVERAGE ──────────────────────────────────────────────────┐"
emit "│ cores: $CORES"
emit "│ load:  $LOAD1 (1m)  $LOAD5 (5m)  $LOAD15 (15m)"
emit "│ ratio: $(echo "scale=2; $LOAD1 / $CORES" | bc) (1m)  $(echo "scale=2; $LOAD5 / $CORES" | bc) (5m)  $(echo "scale=2; $LOAD15 / $CORES" | bc) (15m)"
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- cpu breakdown ---
emit "┌─ CPU BREAKDOWN ─────────────────────────────────────────────────┐"
if command -v mpstat &>/dev/null; then
  MPSTAT_OUT=$(mpstat 1 1 2>/dev/null | tail -1 | awk '{printf "│ user: %s%%  system: %s%%  iowait: %s%%  idle: %s%%\n", $3, $5, $6, $12}' || true)
  if [[ -n "$MPSTAT_OUT" ]]; then
    emit "$MPSTAT_OUT"
  else
    emit "│ (mpstat output unavailable)"
  fi
else
  # fallback: parse /proc/stat
  read -r _ user nice system idle iowait _ < /proc/stat
  total=$((user + nice + system + idle + iowait))
  emit "│ user: $((user * 100 / total))%  system: $((system * 100 / total))%  iowait: $((iowait * 100 / total))%  idle: $((idle * 100 / total))%"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- memory ---
MEM_TOTAL_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
MEM_AVAIL_KB=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
MEM_FREE_KB=$(awk '/MemFree/{print $2}' /proc/meminfo)
MEM_CACHED_KB=$(awk '/^Cached/{print $2}' /proc/meminfo)
MEM_BUFFERS_KB=$(awk '/Buffers/{print $2}' /proc/meminfo)
MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
MEM_TOTAL_GB=$(echo "scale=1; $MEM_TOTAL_KB / 1048576" | bc)
MEM_AVAIL_GB=$(echo "scale=1; $MEM_AVAIL_KB / 1048576" | bc)
MEM_USED_GB=$(echo "scale=1; $MEM_USED_KB / 1048576" | bc)
MEM_CACHED_GB=$(echo "scale=1; $MEM_CACHED_KB / 1048576" | bc)
MEM_AVAIL_PCT=$((MEM_AVAIL_KB * 100 / MEM_TOTAL_KB))

# swap
SWAP_TOTAL_KB=$(awk '/SwapTotal/{print $2}' /proc/meminfo)
SWAP_FREE_KB=$(awk '/SwapFree/{print $2}' /proc/meminfo)
SWAP_USED_KB=$((SWAP_TOTAL_KB - SWAP_FREE_KB))
if [[ $SWAP_TOTAL_KB -gt 0 ]]; then
  SWAP_TOTAL_GB=$(echo "scale=1; $SWAP_TOTAL_KB / 1048576" | bc)
  SWAP_USED_GB=$(echo "scale=1; $SWAP_USED_KB / 1048576" | bc)
  SWAP_USED_PCT=$((SWAP_USED_KB * 100 / SWAP_TOTAL_KB))
else
  SWAP_TOTAL_GB="0"
  SWAP_USED_GB="0"
  SWAP_USED_PCT=0
fi

emit "┌─ MEMORY ─────────────────────────────────────────────────────────┐"
emit "│ total:     ${MEM_TOTAL_GB}G"
emit "│ used:      ${MEM_USED_GB}G ($((100 - MEM_AVAIL_PCT))%)"
emit "│ available: ${MEM_AVAIL_GB}G (${MEM_AVAIL_PCT}%)"
emit "│ cached:    ${MEM_CACHED_GB}G"
emit "│ swap:      ${SWAP_USED_GB}G / ${SWAP_TOTAL_GB}G (${SWAP_USED_PCT}%)"
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- top cpu processes ---
emit "┌─ TOP 15 CPU PROCESSES ───────────────────────────────────────────┐"
ps aux --sort=-%cpu | head -16 | tail -15 | while read -r user pid cpu mem vsz rss tty stat start time cmd; do
  # dead-on-read: process exited between the ps snapshot and this re-read.
  # report it as exited rather than fake an age from system uptime.
  if [[ ! -r /proc/$pid/stat ]]; then
    emit "│ [exited]"
    emit "│   pid=$pid  cpu=${cpu}%  mem=${mem}%  (gone before re-read)"
    emit "│"
    continue
  fi
  comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
  cwd=$(readlink /proc/$pid/cwd 2>/dev/null | sed "s|^$HOME|~|" || echo "?")
  # elapsed time — only trust a real start time; else show "?"
  clk_tck=$(getconf CLK_TCK)
  uptime_sec=$(awk '{print int($1)}' /proc/uptime)
  starttime=$(awk '{print $22}' /proc/$pid/stat 2>/dev/null)
  elapsed="?"
  if [[ -n "$starttime" && "$starttime" -gt 0 ]]; then
    start_sec=$((starttime / clk_tck))
    elapsed_sec=$((uptime_sec - start_sec))
    elapsed_min=$((elapsed_sec / 60))
    elapsed_hr=$((elapsed_min / 60))
    if [[ $elapsed_hr -gt 0 ]]; then
      elapsed="${elapsed_hr}h$((elapsed_min % 60))m"
    elif [[ $elapsed_min -gt 0 ]]; then
      elapsed="${elapsed_min}m"
    else
      elapsed="${elapsed_sec}s"
    fi
  fi
  emit "│ $comm"
  emit "│   pid=$pid  cpu=${cpu}%  mem=${mem}%  elapsed=$elapsed"
  emit "│   cwd=$cwd"
  emit "│   cmd=${cmd:0:70}"
  emit "│"
done
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- top mem processes ---
emit "┌─ TOP 15 MEM PROCESSES ───────────────────────────────────────────┐"
ps aux --sort=-%mem | head -16 | tail -15 | while read -r user pid cpu mem vsz rss tty stat start time cmd; do
  comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
  rss_mb=$((rss / 1024))
  emit "│ $comm"
  emit "│   pid=$pid  mem=${mem}% (${rss_mb}MB)  cpu=${cpu}%"
  emit "│   cmd=${cmd:0:70}"
  emit "│"
done
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- d-state processes (blocked on I/O) ---
emit "┌─ D-STATE PROCESSES (blocked on I/O) ─────────────────────────────┐"
DSTATE=$(ps aux | awk '$8 ~ /D/ {print $2, $11}' | head -10)
if [[ -n "$DSTATE" ]]; then
  echo "$DSTATE" | while read -r pid cmd; do
    emit "│ pid=$pid  cmd=$cmd"
  done
else
  emit "│ (none)"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- zombie processes ---
emit "┌─ ZOMBIE PROCESSES ───────────────────────────────────────────────┐"
ZOMBIES=$(ps aux | awk '$8 == "Z" {print $2, $11}' | head -10)
if [[ -n "$ZOMBIES" ]]; then
  echo "$ZOMBIES" | while read -r pid cmd; do
    emit "│ pid=$pid  cmd=$cmd"
  done
else
  emit "│ (none)"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- disk I/O ---
emit "┌─ DISK I/O ───────────────────────────────────────────────────────┐"
if command -v iostat &>/dev/null; then
  IOSTAT_OUT=$(iostat -dx 1 1 2>/dev/null | tail -n +4 | head -10 || true)
  if [[ -n "$IOSTAT_OUT" ]]; then
    echo "$IOSTAT_OUT" | while read -r line; do
      emit "│ $line"
    done
  else
    emit "│ (no iostat output)"
  fi
else
  emit "│ (iostat not available; install sysstat)"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- file descriptors ---
emit "┌─ FILE DESCRIPTORS ───────────────────────────────────────────────┐"
FD_USED=$(cat /proc/sys/fs/file-nr | awk '{print $1}')
FD_MAX=$(cat /proc/sys/fs/file-nr | awk '{print $3}')
emit "│ used: $FD_USED / $FD_MAX"
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- network connections ---
emit "┌─ NETWORK CONNECTIONS ────────────────────────────────────────────┐"
if command -v ss &>/dev/null; then
  ESTABLISHED=$(ss -t state established | wc -l)
  TIME_WAIT=$(ss -t state time-wait | wc -l)
  LISTEN_COUNT=$(ss -tln | wc -l)
  emit "│ established: $ESTABLISHED  time-wait: $TIME_WAIT  listen: $LISTEN_COUNT"
else
  emit "│ (ss not available)"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- recent kernel messages ---
emit "┌─ RECENT KERNEL MESSAGES (last 20) ───────────────────────────────┐"
DMESG_OUT=$(dmesg --time-format iso 2>/dev/null | tail -20 || true)
if [[ -n "$DMESG_OUT" ]]; then
  echo "$DMESG_OUT" | while read -r line; do
    emit "│ ${line:0:70}"
  done
else
  emit "│ (dmesg not accessible - may require sudo)"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- temperatures ---
emit "┌─ TEMPERATURES ───────────────────────────────────────────────────┐"
if command -v sensors &>/dev/null; then
  sensors 2>/dev/null | grep -E '(Core|temp|Tctl|Tdie)' | head -10 | while read -r line; do
    emit "│ $line"
  done
else
  # fallback: check thermal zones
  for tz in /sys/class/thermal/thermal_zone*/temp; do
    if [[ -f "$tz" ]]; then
      name=$(basename "$(dirname "$tz")")
      temp=$(cat "$tz" 2>/dev/null || echo "0")
      temp_c=$((temp / 1000))
      emit "│ $name: ${temp_c}°C"
    fi
  done
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- process counts ---
emit "┌─ PROCESS COUNTS ─────────────────────────────────────────────────┐"
TOTAL_PROCS=$(ps aux | wc -l)
ACTIVE=$(ps aux | awk '$8 ~ /R/ {count++} END {print count+0}')
IDLE=$(ps aux | awk '$8 ~ /S/ {count++} END {print count+0}')
emit "│ total: $TOTAL_PROCS  active: $ACTIVE  idle: $IDLE"
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

# --- top open files by process ---
emit "┌─ TOP 10 PROCESSES BY OPEN FILES ─────────────────────────────────┐"
# collect open file counts safely
OPEN_FILES_DATA=$(
  for pid in $(ps -eo pid --no-headers 2>/dev/null | head -100); do
    if [[ -d /proc/$pid/fd ]]; then
      count=$(ls -1 /proc/$pid/fd 2>/dev/null | wc -l || echo "0")
      comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
      echo "$count $pid $comm"
    fi
  done 2>/dev/null | sort -rn | head -10 || true
)
if [[ -n "$OPEN_FILES_DATA" ]]; then
  echo "$OPEN_FILES_DATA" | while read -r count pid comm; do
    emit "│ $comm (pid=$pid): $count open files"
  done
else
  emit "│ (no data)"
fi
emit "└─────────────────────────────────────────────────────────────────┘"
emit ""

emit "═══════════════════════════════════════════════════════════════════"

if [[ $STDOUT_MODE -eq 0 ]]; then
  echo "📸 snapshot saved: $OUTFILE"
fi
SNAPSHOT_SCRIPT

  chmod +x "$bin_path"
  echo "• machine_usage_snapshot installed ($bin_path)"
}
