#!/usr/bin/env bash
#########################
## install_env.pt1.system.security.sh
##
## security procedures for two-way flatpak isolation.
##
## procedures:
##   configure_yama_ptrace    - set kernel ptrace_scope to admin-only
##   configure_firefox_isolation - apply flatpak overrides for firefox
##
## usage:
##   source ~/git/more/dev-env-setup/src/install_env.pt1.system.security.sh
##   configure_yama_ptrace
##   configure_firefox_isolation
#########################

set -euo pipefail

#########################
## configure_yama_ptrace
##
## sets yama ptrace_scope to 2 (admin-only).
## blocks same-uid processes from ptrace attach.
## requires sudo.
##
## idempotent: safe to re-run.
#########################
configure_yama_ptrace() {
  local current_scope
  current_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null) || current_scope="unknown"

  # idempotent guard
  if [[ "$current_scope" == "2" ]]; then
    echo "• yama ptrace_scope already set to 2 (skip)"
    return 0
  fi

  echo "• set yama ptrace_scope to 2 (admin-only)"

  # write sysctl config
  local sysctl_file="/etc/sysctl.d/99-yama-ptrace.conf"
  echo "kernel.yama.ptrace_scope = 2" | sudo tee "$sysctl_file" > /dev/null

  # reload sysctl
  sudo sysctl --system > /dev/null

  # verify
  current_scope=$(cat /proc/sys/kernel/yama/ptrace_scope)
  if [[ "$current_scope" == "2" ]]; then
    echo "  ✓ ptrace_scope now 2"
  else
    echo "  ✗ failed to set ptrace_scope (got $current_scope)"
    return 1
  fi
}

#########################
## check_portal_prereqs
##
## verifies xdg-desktop-portal is installed.
## warns if absent.
#########################
check_portal_prereqs() {
  if ! command -v /usr/libexec/xdg-desktop-portal &>/dev/null && \
     ! command -v xdg-desktop-portal &>/dev/null && \
     ! flatpak info org.freedesktop.Platform 2>/dev/null | grep -q "desktop-portal"; then
    echo "  warn: xdg-desktop-portal may not be installed"
    echo "        file picker may not work without it"
    echo "        install with: sudo apt install xdg-desktop-portal"
  fi
}

#########################
## configure_firefox_isolation
##
## applies flatpak overrides for firefox:
##   - remove filesystem access (home, host)
##   - remove x11 socket access
##   - keep wayland socket
##   - block access to secret service
##
## idempotent: safe to re-run.
#########################
configure_firefox_isolation() {
  local override_file="$HOME/.local/share/flatpak/overrides/org.mozilla.firefox"

  # check if firefox flatpak is installed
  if ! flatpak info org.mozilla.firefox &>/dev/null; then
    echo "• firefox flatpak not installed (skip)"
    return 0
  fi

  # check portal prereqs
  check_portal_prereqs

  # idempotent guard: check if our overrides already applied
  if [[ -f "$override_file" ]]; then
    if grep -q "nosocket=x11" "$override_file" && \
       grep -q "nofilesystem=home" "$override_file"; then
      echo "• firefox flatpak overrides already applied (skip)"
      return 0
    fi
  fi

  echo "• apply firefox flatpak isolation overrides"

  # apply overrides
  flatpak override --user org.mozilla.firefox \
    --nofilesystem=home \
    --nofilesystem=host \
    --nosocket=x11 \
    --nosocket=fallback-x11 \
    --socket=wayland \
    --no-talk-name=org.freedesktop.secrets

  echo "  ✓ overrides applied"
  echo ""
  echo "  applied flags:"
  echo "    --nofilesystem=home"
  echo "    --nofilesystem=host"
  echo "    --nosocket=x11"
  echo "    --nosocket=fallback-x11"
  echo "    --socket=wayland"
  echo "    --no-talk-name=org.freedesktop.secrets"
  echo ""
  echo "  verify with: flatpak override --user --show org.mozilla.firefox"
}
