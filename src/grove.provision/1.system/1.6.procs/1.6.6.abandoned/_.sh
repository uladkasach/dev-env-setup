#!/usr/bin/env bash
######################################################################
# .what = a USER systemd timer that kills, every hour, each process abandoned
#         for over 24h — and logs every kill
#
# .what "abandoned" means — four rules, declared once, in the executable itself
#   `src/machine/machine_resource_procs_reap_abandoned`: ours · spawner dead ·
#   not its cgroup's oldest process · older than 24h
#
# .why a timer
#   - a population of orphans is reaped by age, before memory pressure exists
#   - earlyoom kills one process by score, and once killed the session instead
#     (`gotcha.earlyoom-kills-the-session-not-the-hog`, which holds the measurement)
#
# .why every box, no decline: a grove leaks the same subprocesses, with no human to notice
# .why no linger claim: `1.6.7.linger` runs first and owns that one fact
#
# ⚠️ .why the service is generated and the timer is an asset
#   - the ExecStart names THIS checkout's executable; the timer holds no path (`cmp`-able)
#   - ⇒ apply `--from main`; a `--from tree` apply binds it to a deletable worktree
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

# .what = whether the unit at $1 holds the declared service bytes, exact
# .why  = a pipe into `cmp -s -` leaves its writer on EPIPE when cmp exits before it reads
#         (an absent unit); where SIGPIPE is ignored, as on a CI runner, the writer prints
#         `write error: Broken pipe` into the phase's own output. each side is read whole,
#         a sentinel keeps the final newlines, and no pipe is left to break
grove_provision_1_6_6_abandoned_service_matches() {
  local unit="$1" want got
  [[ -f "$unit" ]] || return 1
  want="$(grove_provision_1_6_6_abandoned_service_text; printf x)"
  got="$(cat -- "$unit"; printf x)"
  [[ "$want" == "$got" ]]
}

grove_provision_1_6_6_abandoned() {
  bundle.upgrade 1.6.6.abandoned.provision.upsert
  bundle.upgrade 1.6.6.abandoned.provision.verify
}
