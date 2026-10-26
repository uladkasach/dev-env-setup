#!/usr/bin/env bash
######################################################################
# .what = earlyoom — the daemon that kills a memory hog BEFORE the kernel's own
#         oom killer would, so the box stays reachable instead of it locks up
#
# .why its own leaf: no one asks — its output is the kill (the split: `1.6.procs/_.sh`)
#
# ⚠️ .why a grove needs this MOST, and so it carries NO decline
#   - the kernel's oom killer fires once the box thrashes, when sshd cannot be scheduled
#   - earlyoom acts while the box still answers, and a kill needs no screen
#
# usage:
#   rhx grove.provision --what 1.6.3.earlyoom --mode apply
######################################################################

# .what = does the LIVE earlyoom process carry the declared --avoid policy?
# .why  = one reader for both configure halves: /etc/default/earlyoom is read once
#         at start, so only the process's own argv says the policy is in force
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
