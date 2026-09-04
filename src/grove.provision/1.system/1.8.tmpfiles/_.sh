#!/usr/bin/env bash
######################################################################
# .what = a daily systemd timer that prunes /tmp entries older than 3 days
#
# .why  it is a BOOT-TIME concern, not a disk-space one
#         `systemd-tmpfiles-setup.service` walks /tmp on every boot and blocks
#         until it finishes. on a box with a full-disk-encrypted root and a month
#         between reboots, that walk has been measured at 4+ minutes — so the box
#         appears to hang on a black screen and a human power-cycles it, which is
#         how a slow boot becomes a corrupt filesystem.
#
#         ref: https://github.com/pop-os/pop/issues/1048
#
#         so the timer's value is not the bytes it reclaims; it is that /tmp stays
#         small enough for the boot-time walk to be instant.
#
# .why  it applies EVERYWHERE, even where there is no LUKS
#         the incident above is a laptop's, but the mechanism is not: any box
#         whose /tmp accumulates pays the walk at boot, and a grove reboots on a
#         schedule its human does not watch. a slow boot on a headless box reads
#         as an unreachable box.
#
# usage:
#   rhx grove.provision --what 1.8.tmpfiles --mode apply
######################################################################

grove_provision_1_8_tmpfiles() {
  bundle.upgrade 1.8.tmpfiles.provision.upsert
  bundle.upgrade 1.8.tmpfiles.provision.verify
}
