#!/usr/bin/env bash
######################################################################
# .what = earlyoom — the daemon that kills a memory hog BEFORE the kernel's own
#         oom killer would, so the box stays reachable instead of it locks up
#
# .why  it is a THIRD leaf here and not part of `1.6.2.monitor`
#         the three leaves are three answers to one subject — a runaway process:
#
#           1.6.1.finders   a human ASKS what consumes the box
#           1.6.2.monitor   a timer asks on the human's behalf, and alerts
#           1.6.3.earlyoom  no one asks; the kernel-adjacent daemon just kills
#
#         they fail apart, and a reader must act differently on each. an absent
#         finder means a wedged box cannot be diagnosed; an absent earlyoom means
#         a wedged box cannot be REACHED to run the finder. that is the split test
#         (rule.require.bundle-names-name-their-subject).
#
# ⚠️ .why a grove needs this MOST
#         linux's own oom killer fires only once the box already thrashes — by
#         which time sshd cannot get scheduled, so a headless box drops off the
#         network and the only cure is a hard stop from the console. earlyoom acts
#         while the box still answers.
#
#         so this leaf carries NO decline. it is the mirror of `1.6.2.monitor`,
#         which declines on a grove because its output needs a human's screen;
#         this one's output IS the kill, and a kernel needs no screen.
#
# usage:
#   rhx grove.provision --what 1.6.3.earlyoom --mode apply
######################################################################

grove_provision_1_6_3_earlyoom() {
  bundle.upgrade 1.6.3.earlyoom.provision.upsert
  bundle.upgrade 1.6.3.earlyoom.provision.verify
}
