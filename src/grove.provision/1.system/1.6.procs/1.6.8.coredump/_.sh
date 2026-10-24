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
#   - the upsert's `sysctl --system` replaces apport as the LIVE collector on every tier;
#     it also turns apport's boot claim off (`enabled=0`), or the next boot hands the
#     pattern back to apport. it never stops the apport service: `do_stop` would reset
#     the live pattern to `core`
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

# .what = where apport's init entry and its on/off switch live
# .why  = overridable, so a clamp can read fixtures rather than the box
grove_provision_1_6_8_coredump_apport_init_path() {
  printf '%s' "${GROVE_APPORT_INIT_PATH:-/etc/init.d/apport}"
}
grove_provision_1_6_8_coredump_apport_default_path() {
  printf '%s' "${GROVE_APPORT_DEFAULT_PATH:-/etc/default/apport}"
}

# .what = will apport take core_pattern back at the next boot?
# .why  = the live pattern proves only NOW. apport's init `do_start` writes its own pipe into
#   core_pattern with no condition, and it starts after `systemd-sysctl`, so an enabled apport
#   wins every boot — the next crash then leaves no core, and apport skips an unpackaged
#   `/usr/local/bin/tmux` besides. the init reads `enabled=1` as its default, so a switch file
#   with no `enabled=` line still claims the boot
grove_provision_1_6_8_coredump_apport_claims_boot() {
  local init default enabled=1 line
  init="$(grove_provision_1_6_8_coredump_apport_init_path)"
  default="$(grove_provision_1_6_8_coredump_apport_default_path)"
  [[ -e "$init" ]] || return 1
  if [[ -r "$default" ]]; then
    line="$(grep -E '^[[:space:]]*enabled=' "$default" | tail -1)"
    [[ -n "$line" ]] && enabled="${line#*=}"
  fi
  [[ "$enabled" == 1 ]]
}

grove_provision_1_6_8_coredump() {
  bundle.upgrade 1.6.8.coredump.provision.upsert
  bundle.upgrade 1.6.8.coredump.provision.verify
}
