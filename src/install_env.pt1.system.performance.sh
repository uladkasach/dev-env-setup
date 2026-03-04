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

  local bin_path="$HOME/.local/bin/check-runaway-procs"
  local service_path="$HOME/.config/systemd/user/runaway-monitor.service"
  local timer_path="$HOME/.config/systemd/user/runaway-monitor.timer"

  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.config/systemd/user"

  # create the monitor executable
  cat > "$bin_path" << 'MONITOR'
#!/bin/bash
#############################
# check-runaway-procs
# monitors CPU load and memory, notifies on threshold breach
#############################

# import graphical session env for notify-send (works on both X11 and Wayland)
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
  export $(systemctl --user show-environment | grep -E '^(DISPLAY|WAYLAND_DISPLAY|DBUS_SESSION_BUS_ADDRESS)=')
fi

LOAD=$(awk '{print $1}' /proc/loadavg)
CORES=$(nproc)
LOAD_THRESHOLD=$(echo "$CORES * 1.5" | bc)

# memory: alert if <15% available
MEM_AVAIL_PCT=$(awk '/MemAvailable/{a=$2} /MemTotal/{t=$2} END{printf "%.0f", (a/t)*100}' /proc/meminfo)
MEM_THRESHOLD=15

# check load
LOAD_HIGH=0
if (( $(echo "$LOAD > $LOAD_THRESHOLD" | bc -l) )); then
  LOAD_HIGH=1
fi

# check memory
MEM_LOW=0
if (( MEM_AVAIL_PCT < MEM_THRESHOLD )); then
  MEM_LOW=1
fi

# exit if all good
if [[ $LOAD_HIGH -eq 0 && $MEM_LOW -eq 0 ]]; then
  exit 0
fi

# identify top offenders
TOP_CPU=$(ps aux --sort=-%cpu | awk 'NR>1 && NR<=4 {printf "%s (%.0f%% CPU, %.0f%% MEM, PID %s)\n", $11, $3, $4, $2}')
TOP_MEM=$(ps aux --sort=-%mem | awk 'NR>1 && NR<=4 {printf "%s (%.0f%% MEM, %.0f%% CPU, PID %s)\n", $11, $4, $3, $2}')

# get PIDs for kill command
KILL_PIDS=$(ps aux --sort=-%cpu | awk 'NR>1 && NR<=4 {print $2}' | tr '\n' ' ')

# build message
MSG=""
if [[ $LOAD_HIGH -eq 1 ]]; then
  MSG+="⚠️ HIGH LOAD: $LOAD (threshold: $LOAD_THRESHOLD)\n\n"
  MSG+="Top CPU:\n$TOP_CPU\n\n"
fi
if [[ $MEM_LOW -eq 1 ]]; then
  MSG+="⚠️ LOW MEMORY: ${MEM_AVAIL_PCT}% available\n\n"
  MSG+="Top MEM:\n$TOP_MEM\n\n"
fi
MSG+="━━━━━━━━━━━━━━━━━━━━\n"
MSG+="Fix: kill -9 $KILL_PIDS"

# send notification
notify-send -u critical "🔥 System Resource Alert" "$(echo -e "$MSG")"

# also log it
mkdir -p "$HOME/.local/log"
echo "$(date '+%Y-%m-%d %H:%M:%S') ALERT load=$LOAD mem_avail=${MEM_AVAIL_PCT}% pids=$KILL_PIDS" >> "$HOME/.local/log/runaway-monitor.log"
MONITOR

  chmod +x "$bin_path"

  # create systemd service
  cat > "$service_path" << 'SERVICE'
[Unit]
Description=Check for runaway processes

[Service]
Type=oneshot
ExecStart=%h/.local/bin/check-runaway-procs
SERVICE

  # create systemd timer (every 2 min)
  cat > "$timer_path" << 'TIMER'
[Unit]
Description=Run runaway process check every 2 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
TIMER

  # enable timer
  systemctl --user daemon-reload
  systemctl --user enable --now runaway-monitor.timer

  # verify installation
  if ! command -v bc &>/dev/null; then
    echo "✗ runaway-monitor install failed: bc not available" >&2
    exit 1
  fi
  if ! command -v notify-send &>/dev/null; then
    echo "✗ runaway-monitor install failed: notify-send not available" >&2
    exit 1
  fi
  if ! systemctl --user is-enabled runaway-monitor.timer &>/dev/null; then
    echo "✗ runaway-monitor install failed: timer not enabled" >&2
    exit 1
  fi

  echo "• runaway-monitor installed and enabled (checks every 2 min)"
}
