#!/usr/bin/env bash
######################################################################
# .what = the three runaway-process finders, on PATH
#
#   machine_resource_procs_find_runaway — cpu + memory + swap hogs
#   machine_resource_procs_find_spinner — a process that burns cpu with no work
#   machine_resource_procs_find_orphan  — a process whose parent is gone
#
# .why  three scripts in ONE bundle
#         a bundle is a CONCERN. these three answer one question — *what consumes
#         this box* — from three angles, are installed the same way, fail the
#         same way, and are fixed by the same re-apply. to split them would be
#         three files that differ only in a filename.
#
# .why  it applies to EVERY machine, grove included
#         the name reads like a human's diagnostic, so a `local` gate looks
#         natural. it would be wrong. a laptop that wedges has a human at it who
#         notices; a grove that wedges has nobody, and the only way in is a duct
#         that a runaway may already have starved. these are what a robot calls
#         to diagnose its own box.
#
#         `.agent/repo=.this/role=any/skills/nvim.diagnose.runaway.sh` and
#         `machine.diagnose.lag.sh` both lean on this vocabulary.
#
# .why  it holds no `configure` phase
#         the scripts read no config. every knob is a flag (`--json`, `--full`,
#         `--min N`, `--kill`), passed per call.
#
# usage:
#   rhx grove.provision --what 1.6.1.finders --mode apply
######################################################################

grove_provision_1_6_1_finders() {
  bundle.upgrade 1.6.1.finders.provision.upsert
  bundle.upgrade 1.6.1.finders.provision.verify
}
