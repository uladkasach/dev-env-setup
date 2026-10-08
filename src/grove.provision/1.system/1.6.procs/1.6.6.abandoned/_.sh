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
#   - on 2026-10-07 ~254 abandoned processes (nearly all node) accrued across a
#     35-day session, to 27.4G RAM + 45G swap, and no reader watched for them:
#       · `1.6.4.keyrackd` reaps ONE population, the keyrack daemons
#       · `machine.usage.diagnose` runs only when a human asks
#       · earlyoom kills ONE process by score, and a population of medium
#         orphans never outranked a 4 MiB session daemon — so it killed the
#         session instead (`gotcha.earlyoom-kills-the-session-not-the-hog`)
#   - ⇒ the population has to be reaped by age, before memory pressure exists
#
# .why every box, no decline
#   - a grove leaks the same tool subprocesses, and has no human to notice
#
# .why no linger claim here
#   - `1.6.4.keyrackd` runs first and grants linger to every human seat; this
#     timer rides on the same user manager. a second linger claim would be a
#     second declaration of one fact
#
# ⚠️ .why the service is generated and the timer is an asset
#   - same split as `1.6.4.keyrackd`: the ExecStart names THIS checkout's
#     executable, so it comes from one reader both halves ask; the timer holds
#     no path, so it is a tracked file the verify can `cmp`
#   - ⇒ apply `--from main`. a `--from tree` apply binds the timer to a
#     worktree a `git worktree remove` can delete
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
