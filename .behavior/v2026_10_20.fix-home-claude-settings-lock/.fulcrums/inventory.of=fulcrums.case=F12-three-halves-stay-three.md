# F12 — the three file halves stay three, not one converge engine

- **fork**: extract one `converge_json_file({ target, program, patch }, { backup, lock, shrinkGuard })`
  that the settings, global config, and keybindings halves each declare against (r011 nitpick.3),
  vs keep three halves that share their leaves (`tmp_mint`, `tmp_guard`, `plain_swap`,
  `json_equivalence`, the readers in `_.sh`)
- **taken**: keep three, in this route. the shared leaves already carry the swap, the tmp, and
  the trap; what differs is policy, and the policies differ on purpose:
  - settings: backup, strip, 0444 swap, boot gate
  - global config (the oauth session): never a backup of 750KB of project state, a SHRANK guard
  - keybindings: a compare, never a backup
- **rework**: dirty — every half and some sixty clamp arms bind to the halves' names and verdicts.
  an engine changes all three halves' flow at once, in a route whose wish names one file
- **what it owes**: the dream `v2026_10_23.refactor.5-3-brains-one-converge-engine.md`, symlinked
  at `$route/dreams/`
- **confidence 80%, low because**: r011 is right that the rule of three is met; the call to defer
  is a ripple estimate, not a measurement
- **where**: `configure.upsert.sh`, the three `_*_upsert` halves
- **verdict**: open
