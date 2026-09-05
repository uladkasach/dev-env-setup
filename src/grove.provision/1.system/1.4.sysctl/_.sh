#!/usr/bin/env bash
######################################################################
# .what = the kernel parameters in `/etc/sysctl.conf` that this repo's workload
#         needs raised from their stock values
#
# .why it is named for the FILE it declares, not for a quality
#         an earlier draft called this `1.4.performance` and nested a `1.4.1.kernel`
#         under it. both halves were wrong:
#
#           - "performance" is an OUTCOME, not a concern. you cannot install it, so
#             no bundle can own it — and any bundle could claim to serve it. a dir
#             named for a quality collects whatever a writer felt was related.
#           - "kernel" is a LAYER, not a subset of performance, so the nest asserted
#             a hierarchy that does not exist.
#
#         `sysctl` names exactly one interface: the one this bundle writes to. a
#         reader knows its scope from the name, and a later concern cannot drift in.
#         (rule.require.bundle-names-name-their-subject)
#
# .why swap is a SEPARATE bundle (`1.5.swap`)
#         they shared one file at first, and that was the tell. a sysctl key is a
#         line in a config file; a swapfile is a block device to allocate, label,
#         and arm — with a hibernation conflict to defer around. they fail
#         differently, they prove differently, and only one of them can stall a
#         boot. one bundle, one concern.
#
# .why it holds NO provision phase
#         these are declarations against a kernel that is already present. there is
#         no package to install, so the bundle has a configure pair and no other
#         phase. a phase list is what a bundle HAS, never a template it must fill.
#
# .why it applies to every machine
#         a grove runs the same file watchers as a laptop and has less ram to do it
#         with (rule.require.identical-bundle-composition).
#
# usage:
#   rhx grove.provision --what 1.4.sysctl --mode apply
######################################################################

grove_provision_1_4_sysctl() {
  bundle.upgrade 1.4.sysctl.configure.upsert
  bundle.upgrade 1.4.sysctl.configure.verify
}
