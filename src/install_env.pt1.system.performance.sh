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
  #############################
  local swapfile="/swapfile"
  local size="36G"

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
KILL_MODE=""
KILL_TYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_MODE=1; shift ;;
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
        echo "Usage: machine_resource_procs_find_runaway [--json | --kill cpu | --kill mem | --kill <prefix> [cpu|mem]]" >&2
        exit 1
      fi
      ;;
    *)
      echo "Usage: machine_resource_procs_find_runaway [--json | --kill cpu | --kill mem | --kill <prefix> [cpu|mem]]" >&2
      exit 1
      ;;
  esac
done

LOAD=$(awk '{print $1}' /proc/loadavg)
CORES=$(nproc)
LOAD_THRESHOLD=$(echo "$CORES * 1.5" | bc)

MEM_AVAIL_PCT=$(awk '/MemAvailable/{a=$2} /MemTotal/{t=$2} END{printf "%.0f", (a/t)*100}' /proc/meminfo)
MEM_THRESHOLD=15

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
  echo "$ps_output" | awk -v mode="$mode" 'NR>1 && NR<=4 {
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
  echo "$1" | awk 'NR>1 && NR<=4 {print $2}' | tr '\n' ' '
}

TOP_CPU=$(format_top_procs "$PS_BY_CPU" "cpu")
TOP_MEM=$(format_top_procs "$PS_BY_MEM" "mem")
CPU_PIDS=$(extract_pids "$PS_BY_CPU")
MEM_PIDS=$(extract_pids "$PS_BY_MEM")

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

if [[ $LOAD_HIGH -eq 0 && $MEM_LOW -eq 0 ]]; then
  echo "🐈 lets prowl..."
  echo "└─🌕 runaway"
  echo "  └─✨ system smooth (load=$LOAD, mem=${MEM_AVAIL_PCT}%)"
  exit 0
fi

echo "🐈 lets prowl..."
echo "└─🌕 runaway"
print_proc_details() {
  local pid="$1"
  local cpu="$2"
  local mem="$3"
  local prefix="$4"
  local comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
  local cwd=$(readlink /proc/$pid/cwd 2>/dev/null | sed "s|^$HOME|~|" || echo "?")
  local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | cut -c1-60 || echo "?")
  echo "${prefix}├─ 🐛 $comm (${cpu}% CPU, ${mem}% MEM, PID $pid)"
  echo "${prefix}│     ├─ cwd: $cwd"
  echo "${prefix}│     └─ cmd: $cmdline"
}

if [[ $LOAD_HIGH -eq 1 ]]; then
  echo "  ├─🕯️ high load: $LOAD (threshold: $LOAD_THRESHOLD)"
  echo "$PS_BY_CPU" | awk 'NR>1 && NR<=4 {printf "%s %s %s\n", $2, $3, $4}' | while read pid cpu mem; do
    print_proc_details "$pid" "${cpu%.*}" "${mem%.*}" "  │    "
  done
  echo "  │    └─ 🪄 kill -9 $CPU_PIDS"
fi
if [[ $MEM_LOW -eq 1 ]]; then
  echo "  ├─🕯️ low memory: ${MEM_AVAIL_PCT}% available"
  echo "$PS_BY_MEM" | awk 'NR>1 && NR<=4 {printf "%s %s %s\n", $2, $3, $4}' | while read pid cpu mem; do
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
