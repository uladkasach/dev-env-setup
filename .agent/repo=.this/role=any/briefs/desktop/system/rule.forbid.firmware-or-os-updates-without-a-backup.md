# rule.forbid.firmware-or-os-updates-without-a-backup

## .what

**never recommend a firmware, kernel, or os package update as a fix — until the human
confirms a full backup, AND you have read what the update changes for THIS machine.**

covered: `linux-firmware`, `firmware-*`, kernel packages, bios / me firmware, `fwupdmgr`,
`apt upgrade` / `full-upgrade`, a distro release upgrade.

## .why

- **the blast radius is the whole box.** `linux-firmware` feeds wifi, bluetooth, gpu, and
  audio at once. a regression in one leaves a laptop with no network or no screen
- **all kernels share one firmware tree.** a bad firmware is not escaped by an older kernel
  in the boot menu
- **the defect surfaces late.** firmware loads at the next boot, so the cost lands after the
  conversation that recommended it is over
- **an update can rebuild the initramfs.** an interruption mid-write can leave the box
  unbootable
- **"newer" is not a diagnosis.** an update fixes a defect only if its changelog names this
  platform. otherwise it is risk with no reward

## .the gate — all three, in order

1. **backup** — ask whether the human holds a full, current backup. no → stop. no firmware or
   os update is recommended, however plausible
2. **changelog** — read the candidate's changelog. does it name THIS platform (chip, codec,
   device id)? no → it cannot fix this defect; do not recommend it
3. **rollback** — name how to undo it before you hand it over: the prior package version,
   where its `.deb` sits, and what the human does if the next boot has no network or screen

only after all three: present it as an OPTION with its risk, never as "safe" and never as the
fix of the day.

## .instead, for a broken device today

- a reset the box supports (driver reload, power cycle), with its limits stated
- a workaround that bypasses the broken device (an external usb or bluetooth device)

## .enforcement

- a firmware or os update recommended before a backup is confirmed = **blocker**
- an update recommended whose changelog was not read for this platform = **blocker**
- an update called "safe" or "low risk" with no changelog read = **blocker**
- an update handed over with no rollback named = **blocker**

## .see also

- `rule.require.trust-but-verify` — "newer firmware fixes it" is a claim, owed a check
- `rule.require.security-paramount` — the box's availability is part of its security
