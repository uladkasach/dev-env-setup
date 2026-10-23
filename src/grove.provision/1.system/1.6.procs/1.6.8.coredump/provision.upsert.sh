#!/usr/bin/env bash
######################################################################
# .what = install systemd-coredump, and make the kernel hand it each core
#
# guarantee:
#   - idempotent: a kernel that already pipes to systemd-coredump short-circuits
#   - a seat with no root DECLINES; the verify still ✋s
######################################################################

grove_provision_1_6_8_coredump_provision_upsert() {
  if grove_provision_1_6_8_coredump_collects; then
    echo "   • the kernel already pipes each core to systemd-coredump"
    return 0
  fi

  bundle.root.owns "the crash collector" \
    "core_pattern: $(grove_provision_1_6_8_coredump_pattern)" \
    || return 0

  pkg_install systemd-coredump || {
    echo "   ✋ ConstraintError: systemd-coredump did not install" >&2
    echo "      ⇒ a crash on this box still leaves no core to read" >&2
    echo "      read why: sudo apt-get install systemd-coredump" >&2
    return 1
  }

  # the package's sysctl.d drop-in sets the pattern; apply it now, not at next boot.
  # stdout is every key it set (noise); stderr is why one failed, so it stays
  sudo sysctl --system >/dev/null

  if ! grove_provision_1_6_8_coredump_collects; then
    echo "   ✋ ConstraintError: systemd-coredump is installed, and the kernel still pipes cores elsewhere" >&2
    echo "      ⇒ another handler (apport, a sysctl.d file) holds core_pattern" >&2
    echo "      read why: cat $(grove_provision_1_6_8_coredump_pattern_path) ; sysctl --system" >&2
    return 1
  fi
  echo "   • systemd-coredump collects each core; read them with coredumpctl"
}
