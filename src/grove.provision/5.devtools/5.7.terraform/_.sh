#!/usr/bin/env bash
######################################################################
# .what = terraform, via tfenv
#
# .tfenv, never terraform directly
#   - every stack pins its own version in `required_version`
#   - ⇒ one global binary cannot satisfy two stacks that disagree
#   - tfenv reads the pin per-directory and picks the matched build
#
# 🛑 .it installs EVERYWHERE. do NOT re-add a `local@*` gate
#   - terraform here applies the vpc and the ec2 boxes the groves run on, so an
#     apply's blast radius reaches past the machine that runs it
#   - ⇒ what bounds that blast radius is WHICH AWS ROLE the box may assume, and
#     a binary on the disk changes that not at all
#   - a gate on the BINARY is a proxy for a human's presence, and it fails both
#     ways (`rule.forbid.tty-as-a-proxy-for-a-human`, the same shape one axis over):
#     - it blocks `plan`, `validate`, `fmt`, `show` — every one read-only
#     - it stops no apply, since a seat that wants one fetches a release in a
#       line, which is the ad-hoc path `rule.forbid.adhoc-shell` forbids
#   - ⇒ so the gate cost the safe half and bought no safety
#
# usage:
#   rhx grove.provision --what 5.7.terraform --mode apply
######################################################################

grove_provision_5_7_terraform() {
  bundle.upgrade 5.7.terraform.provision.upsert
  bundle.upgrade 5.7.terraform.provision.verify
}
