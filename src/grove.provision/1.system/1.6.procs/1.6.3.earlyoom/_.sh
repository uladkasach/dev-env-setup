#!/usr/bin/env bash
######################################################################
# .what = earlyoom — the daemon that kills a memory hog BEFORE the kernel's own
#         oom killer would, so the box stays reachable instead of it locks up
#
# .why
#   - a box past the kernel's oom point drops sshd, so earlyoom acts first
#   - it carries no decline, since its output is the kill and needs no screen
#   - the three runaway bundles and why each stands apart: `system.runaway_monitor.spec`
#
# usage:
#   rhx grove.provision --what 1.6.3.earlyoom --mode apply
######################################################################

# .what = does the LIVE earlyoom process carry the declared --avoid policy?
# .why  = one reader for both configure phases. only the process's own argv
#         says whether the policy is in force, since the default file is read once
grove_provision_1_6_3_earlyoom_daemon_runs_policy() {
  local pid
  pid="$(systemctl show -p MainPID --value earlyoom 2>/dev/null)"
  [[ -n "$pid" && "$pid" != "0" && -r "/proc/$pid/cmdline" ]] || return 1
  tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q -- '--avoid ^(systemd|'
}

grove_provision_1_6_3_earlyoom() {
  bundle.upgrade 1.6.3.earlyoom.provision.upsert
  bundle.upgrade 1.6.3.earlyoom.provision.verify
  bundle.upgrade 1.6.3.earlyoom.configure.upsert
  bundle.upgrade 1.6.3.earlyoom.configure.verify
}
