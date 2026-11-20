# F2 — `1.14.updates` applies on every box, the laptop included

## .the fork

- **A — every `cloud@*`**, laptop declines
- **B — hetzner only**, to match the wish's literal scope
- **C — every box**, laptop included

## .taken

C (was A, re-taken 2026-11-16 on a peer review).

- B diverges between two cloud platforms with no physical reason
- A's laptop reason was "pop-os ships its own updater, and a human picks reboot
  times". `rule.forbid.divergence-without-a-physical-reason` names "a human is at
  this box" as a capability claim, never a physical absence. `unattended-upgrades`
  asks no question, so there is no prompt to gate; the drop-in already forbids a
  reboot
- measured on this laptop: no `/etc/apt/apt.conf.d/50unattended-upgrades`, so the
  package is absent and no second unattended updater runs here today. pop's own
  updater is interactive; unattended-upgrade waits on apt's lock like any client
- the cost, paid once: the laptop plan shows the 1.14 claims until a human runs
  `sudo -v && rhx grove.provision --what 1.14.updates --mode apply` at a terminal

## .rework

clean — the gate was one predicate in `_.sh`; a return to A is one line per phase.

## .confidence — 80%, why low

- pop-specific origins: the drop-in `#clear`s the origin list and allows the
  ubuntu security pockets. a fix that pop ships from its own repo is not applied
  unattended. today none is, so this narrows naught; unmeasured whether the
  human wants pop's pocket added
- unmeasured whether ec2 images already enable `unattended-upgrades` (ubuntu cloud
  images often do); if so the bundle only declares what is there

## .where

`src/grove.provision/1.system/1.14.updates/_.sh` (the gate removed from four phases).

## .verdict

open — the human may return to A with a physical reason, or add pop's pocket.
