#!/usr/bin/env bash
######################################################################
# .what = a disk swapfile, at a DECLARED size, for cold pages to spill into
#
#         the size is `GROVE_SWAP_SIZE_GIB`, default 72 — see the ⚠️ in
#         `configure.upsert.sh` for why it is a pin rather than a derivation, and
#         why a box too small for it stops instead of shrinks.
#
# .why at all — the hierarchy
#         RAM → zram (compressed RAM, ~16GB by default) → disk swap (SSD)
#         when zram fills, overflow goes to disk. more disk swap is more headroom.
#
#         the concrete workload: this box hosts brain-cli idlelots. they hold
#         gigabytes and are often left idle, so swap is what lets them give way to a
#         live priority. with no swap the kernel oom-kills a RUNNING process
#         instead, which is the outcome this bundle exists to avoid.
#
# .why it is its own bundle, and not part of `1.4.sysctl`
#         they shared one file at first, and that was the tell. `vm.swappiness` is a
#         line in a config file; a swapfile is a block device to allocate, label, and
#         arm. they fail differently, they prove differently, and only one of them
#         can stall a BOOT. so: one bundle, one concern.
#
# .why it applies to every machine
#         a grove has less ram than the laptop and runs the same idle brains, so it
#         needs this more (rule.require.identical-bundle-composition). it does DEFER
#         on a box that registers its own hibernation swap target — see the upsert;
#         that is a bounded-context boundary, not an applicability decline.
#
# usage:
#   rhx grove.provision --what 1.5.swap --mode apply
######################################################################

grove_provision_1_5_swap() {
  bundle.upgrade 1.5.swap.configure.upsert
  bundle.upgrade 1.5.swap.configure.verify
}
