#!/usr/bin/env bash
######################################################################
# .what = a USER systemd timer that kills, every minute, each grepsafe run
#         older than 2min — with its search children — and logs every kill
#
# .what "runaway" means — declared once, in the executable itself
#   `src/machine/machine_resource_procs_reap_grepsafe`: ours · argv names
#   `claude.tools/grepsafe.sh` · older than 120s
#
# .why a timer, and why this population auto-kills
#   - a grepsafe call is a bounded search that answers in seconds. on
#     2026-10-20 one ran 8 minutes over `.agent` — 3.3G resident, the largest
#     memory holder on a box 29G into swap
#   - the runaway monitor (`1.6.2.monitor`) alerts and lets a human decide; for
#     grepsafe the decision is settled — a runaway is ALWAYS killed — so no ask
#     is owed, and a minute of delay costs gigabytes
#
# .why every box, no decline
#   - a grove's agents call grepsafe too, and no human sits there to notice
#
# ⚠️ .why the service is generated and the timer is an asset
#   - same split as `1.6.6.abandoned`: the ExecStart names THIS checkout's
#     executable; the timer holds no path, so it is a tracked file to `cmp`
#   - ⇒ apply `--from main`
#
# usage:
#   rhx grove.provision --what 1.6.7.grepsafe --mode apply
######################################################################

grove_provision_1_6_7_grepsafe_service_name() { printf 'machine_procs_reap_grepsafe.service'; }
grove_provision_1_6_7_grepsafe_timer_name()   { printf 'machine_procs_reap_grepsafe.timer'; }
grove_provision_1_6_7_grepsafe_unit_dir()     { printf '%s/.config/systemd/user' "$HOME"; }

# .what = the reaper, as an absolute path off THIS run's checkout
grove_provision_1_6_7_grepsafe_bin() {
  printf '%s/machine/machine_resource_procs_reap_grepsafe' "$GROVE_SRC"
}

# .what = the DECLARED service bytes — one reader, asked by both halves
grove_provision_1_6_7_grepsafe_service_text() {
  cat <<SERVICE
[Unit]
Description=Reap grepsafe runs older than 2min

[Service]
Type=oneshot
ExecStart=$(grove_provision_1_6_7_grepsafe_bin) --mode apply --min-age 120
SERVICE
}

grove_provision_1_6_7_grepsafe() {
  bundle.upgrade 1.6.7.grepsafe.provision.upsert
  bundle.upgrade 1.6.7.grepsafe.provision.verify
}
