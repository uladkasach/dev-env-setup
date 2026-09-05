#!/usr/bin/env bash
######################################################################
# .what = terraform, via tfenv
#
# .tfenv, never terraform directly
#   - every stack pins its own version in `required_version`
#   - ⇒ one global binary cannot satisfy two stacks that disagree
#   - tfenv reads the pin per-directory and picks the matched build
#
# .it applies ONLY where a human is
#   - terraform here applies the vpc and the ec2 boxes the groves run on
#   - ⇒ its blast radius reaches beyond the machine, so a human reads the plan
#   - a wake is safe BECAUSE it is reversible, and an apply is not
#     (`rule.require.wake-the-grove-freely`)
#   - ⇒ the decline is about AUTHORITY, never capability
#
# usage:
#   rhx grove.provision --what 5.7.terraform --mode apply
######################################################################

grove_provision_5_7_terraform() {
  bundle.upgrade 5.7.terraform.provision.upsert
  bundle.upgrade 5.7.terraform.provision.verify
}
