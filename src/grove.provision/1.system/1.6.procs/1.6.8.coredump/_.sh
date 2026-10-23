#!/usr/bin/env bash
######################################################################
# .what = a crash on any box leaves a CORE that a human can read with
#         `coredumpctl`, so the next crash is diagnosed rather than guessed
#
# .why
#   - a grove's tmux server segfaulted ~110 times and left no core: the box
#     had no `systemd-coredump`, so the kernel piped each one to naught
#   - a backtrace is the one fact that names a crash's cause; with none, the
#     cure was chosen from a CHANGES line and an offset
#
# .why every tier, the laptop included
#   - systemd-coredump is an ordinary package and core_pattern a kernel knob;
#     both exist on every kind, so no physical fact parts a laptop from a grove
#     (`rule.forbid.divergence-without-a-physical-reason`)
#   - where apport holds the pattern, the upsert ✋s and names it, rather than
#     report a collector that is not the one the kernel calls
#
# usage:
#   rhx grove.provision --what 1.6.8.coredump --mode plan
#   sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply
######################################################################

# .what = where the kernel states its core handler
# .why  = overridable, so a clamp can read a fixture rather than the box
grove_provision_1_6_8_coredump_pattern_path() {
  printf '%s' "${GROVE_CORE_PATTERN_PATH:-/proc/sys/kernel/core_pattern}"
}

# .what = does the kernel hand each core to systemd-coredump?
# .why  = ONE reader, asked by both halves. the PATTERN decides, never the
#   package: apport, or a stale sysctl, can hold the pattern after the install
grove_provision_1_6_8_coredump_collects() {
  local pattern
  pattern="$(grove_provision_1_6_8_coredump_pattern)" || return 1
  [[ "$pattern" == "|"*systemd-coredump* ]]
}

# .what = the core handler the kernel states now; exit 1 where it cannot be read
grove_provision_1_6_8_coredump_pattern() {
  cat "$(grove_provision_1_6_8_coredump_pattern_path)" 2>/dev/null
}

grove_provision_1_6_8_coredump() {
  bundle.upgrade 1.6.8.coredump.provision.upsert
  bundle.upgrade 1.6.8.coredump.provision.verify
}
