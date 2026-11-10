#!/usr/bin/env bash
######################################################################
# .what = prove a crash on this box leaves a core
#
# guarantee:
#   - READ-ONLY. it reads core_pattern
######################################################################

grove_provision_1_6_8_coredump_provision_verify() {
  if grove_provision_1_6_8_coredump_collects && grove_provision_1_6_8_coredump_apport_claims_boot; then
    echo "   ✋ ConstraintError: the kernel pipes each core to systemd-coredump now, and apport takes it back at the next boot" >&2
    echo "      ⇒ apport's init rewrites core_pattern on every boot while enabled=1, after" >&2
    echo "        systemd-sysctl — so the first crash after a reboot leaves no core" >&2
    echo "      read why: cat $(grove_provision_1_6_8_coredump_apport_default_path)" >&2
    echo "      fix: sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply" >&2
    echo "           (on a grove: run it on the ground seat, which holds sudo)" >&2
    return 1
  fi

  if grove_provision_1_6_8_coredump_collects; then
    echo "   • the kernel pipes each core to systemd-coredump, and no apport claims the boot ✔"
    return 0
  fi

  echo "   ✋ ConstraintError: a crash on this box leaves no core systemd-coredump can show" >&2
  echo "      ⇒ core_pattern: $(grove_provision_1_6_8_coredump_pattern || echo unreadable)" >&2
  echo "      ⇒ the next tmux segfault would be guessed at, never read" >&2
  echo "      fix: sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply" >&2
  echo "           (on a grove: run it on the ground seat, which holds sudo)" >&2
  return 1
}
