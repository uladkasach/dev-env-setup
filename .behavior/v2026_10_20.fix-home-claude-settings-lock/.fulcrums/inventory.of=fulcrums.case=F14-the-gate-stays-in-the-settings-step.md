# F14 — the boot gate stays inside the settings step, not a phase of its own

- **fork**: the boot gate runs inside `configure.upsert` (`_settings_step`), so a gate that times
  out or fails on an offline npm fails the upsert, and `bundle.upgrade` then skips
  `configure.verify` on that apply (r011 nitpick.1, i006)
  - **A. keep it in the step** (as built)
  - **B. a phase of its own**: a new phase file the runtime drives after `configure.verify`
- **taken**: A, in this route. a new phase is a change to `bundle.upgrade.sh`'s phase contract,
  which every bundle in the tree shares; this route's wish names one file. the cost of A is
  bounded: the next plan runs the verify, and every gate verdict names its own fix
- **rework**: dirty — the phase set is the runtime's contract (`bundle.upgrade.sh`, the four
  phases), and a fifth phase ripples into every bundle and the plan-apply-apply play
- **what it owes**: the dream `v2026_10_23.refactor.5-3-brains-boot-gate-as-own-phase.md`
- **confidence 75%, low because**: the ripple is estimated from the phase table, not measured
- **where**: `configure.upsert.sh`, `_grove_provision_5_3_brains_settings_step`
- **verdict**: open
