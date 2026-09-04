#!/usr/bin/env bash
######################################################################
# .what = the two commands that report where this machine's resources went —
#         `machine_resource_observe` (a quick read) and `machine_usage_snapshot`
#         (the full capture, written to a file)
#
# .why this bundle exists — the defect it closes
#   - `src/bash_aliases.sh` declared two aliases named after commands no
#     driven step ever installed — dead code an alias made look live
#   - .refs = gotcha.1-7-usage.demo=alias-hid-dead-code.md
#
# .why ONE leaf for two commands, where `1.6.procs` needed three
#   - both are a copy into `~/.local/bin`, both fail by absence, and both
#     are fixed by the same apply, so one leaf with one verify serves them
#
# .why it applies EVERYWHERE
#   - both print to stdout, which a duct reads; a grove needs them most,
#     since a headless box has no system monitor to glance at instead
#
# usage:
#   rhx grove.provision --what 1.7.usage --mode apply
######################################################################

grove_provision_1_7_usage() {
  bundle.upgrade 1.7.usage.provision.upsert
  bundle.upgrade 1.7.usage.provision.verify
}
