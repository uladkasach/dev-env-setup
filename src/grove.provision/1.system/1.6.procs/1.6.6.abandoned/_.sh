#!/usr/bin/env bash
######################################################################
# .what = a USER systemd timer that kills, every hour, each process abandoned
#         for over 24h — and logs every kill
#
# .what "abandoned" means — four rules, declared once, in the executable itself
#   `src/machine/machine_resource_procs_reap_abandoned`: ours · spawner dead ·
#   not its cgroup's oldest process · older than 24h
#
# .why
#   - a population of small orphans is never one process earlyoom would pick
#   - an age-based reap clears it before memory pressure exists
#   - every box runs it, and `1.6.7.linger` runs first and grants the linger it rides on
#   - the measurement and the design: `gotcha.earlyoom-kills-the-session-not-the-hog`
#
# usage:
#   rhx grove.provision --what 1.6.6.abandoned --mode apply
######################################################################

grove_provision_1_6_6_abandoned_service_name() { printf 'machine_procs_reap_abandoned.service'; }
grove_provision_1_6_6_abandoned_timer_name()   { printf 'machine_procs_reap_abandoned.timer'; }
grove_provision_1_6_6_abandoned_unit_dir()     { printf '%s/.config/systemd/user' "$HOME"; }

# .what = the reaper, as an absolute path off THIS run's checkout
grove_provision_1_6_6_abandoned_bin() {
  printf '%s/machine/machine_resource_procs_reap_abandoned' "$GROVE_SRC"
}

# .what = the DECLARED service bytes — one reader, asked by both halves
grove_provision_1_6_6_abandoned_service_text() {
  cat <<SERVICE
[Unit]
Description=Reap processes abandoned for over 24h

[Service]
Type=oneshot
ExecStart=$(grove_provision_1_6_6_abandoned_bin) --mode apply --min-age 86400
SERVICE
}

grove_provision_1_6_6_abandoned() {
  bundle.upgrade 1.6.6.abandoned.provision.upsert
  bundle.upgrade 1.6.6.abandoned.provision.verify
}
