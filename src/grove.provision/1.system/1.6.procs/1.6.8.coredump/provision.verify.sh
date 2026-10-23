#!/usr/bin/env bash
######################################################################
# .what = prove a crash on this box leaves a core
#
# guarantee:
#   - READ-ONLY. it reads core_pattern
######################################################################

grove_provision_1_6_8_coredump_provision_verify() {
  if grove_provision_1_6_8_coredump_collects; then
    echo "   • the kernel pipes each core to systemd-coredump ✔"
    return 0
  fi

  echo "   ✋ ConstraintError: a crash on this box leaves no core systemd-coredump can show" >&2
  echo "      ⇒ core_pattern: $(grove_provision_1_6_8_coredump_pattern || echo unreadable)" >&2
  echo "      ⇒ the next tmux segfault would be guessed at, never read" >&2
  echo "      fix: sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply" >&2
  return 1
}
