#!/usr/bin/env bash
######################################################################
# .what = install systemd-coredump, make the kernel hand it each core, and keep it so
#         across a boot
#
# guarantee:
#   - idempotent: a kernel that already pipes to systemd-coredump, with no apport to
#     take it back at boot, short-circuits
#   - a seat with no root DECLINES; the verify still ✋s
######################################################################

grove_provision_1_6_8_coredump_provision_upsert() {
  if grove_provision_1_6_8_coredump_collects && ! grove_provision_1_6_8_coredump_apport_claims_boot; then
    echo "   • the kernel already pipes each core to systemd-coredump, and no apport claims the boot"
    return 0
  fi

  bundle.root.owns "the crash collector" \
    "core_pattern: $(grove_provision_1_6_8_coredump_pattern)" \
    || return 0

  if ! grove_provision_1_6_8_coredump_collects; then
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
      echo "      ⇒ another handler (a sysctl.d file sorted after the package's) holds core_pattern" >&2
      echo "      read why: cat $(grove_provision_1_6_8_coredump_pattern_path) ; sysctl --system" >&2
      return 1
    fi
  fi

  # apport's init rewrites core_pattern at every boot while it is enabled; turn that claim
  # off, never the service — `do_stop` would reset the live pattern to `core`
  if grove_provision_1_6_8_coredump_apport_claims_boot; then
    grove_provision_1_6_8_coredump_apport_release
    if grove_provision_1_6_8_coredump_apport_claims_boot; then
      echo "   ✋ ConstraintError: apport still claims core_pattern at the next boot" >&2
      echo "      ⇒ the kernel pipes to systemd-coredump now, and apport takes it back at boot," >&2
      echo "        so the first crash after a reboot leaves no core" >&2
      echo "      read why: cat $(grove_provision_1_6_8_coredump_apport_default_path)" >&2
      return 1
    fi
    echo "   • apport's boot claim on core_pattern is off (enabled=0)"
    echo "     ⇒ apport no longer files crash reports into /var/crash; systemd-coredump keeps"
    echo "       each core instead (coredumpctl list)"
    echo "     ⇒ undo: set enabled=1 in $(grove_provision_1_6_8_coredump_apport_default_path);"
    echo "       this bundle's verify then ✋s, since the next boot hands the pattern back to apport"
  fi

  echo "   • systemd-coredump collects each core, across a boot; read them with coredumpctl"
}

# .what = set apport's switch to `enabled=0`, in place, the rest of the file kept
grove_provision_1_6_8_coredump_apport_release() {
  local default; default="$(grove_provision_1_6_8_coredump_apport_default_path)"
  if [[ -e "$default" ]] && grep -qE '^[[:space:]]*enabled=' "$default"; then
    sudo sed -i -E 's/^[[:space:]]*enabled=.*/enabled=0/' "$default"
    return
  fi
  printf 'enabled=0\n' | sudo tee -a "$default" >/dev/null
}
