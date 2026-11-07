# F4 — an empty play index halts `--all`

- fork: leave the empty-index run as is (`0 · 0 · 0`, exit 0), or halt with `✋ ConstraintError`,
  exit 2, before any log
- taken: halt. the reader reads `failed 0` as green, so an empty run writes a false green into the
  very file this change makes primary. the absent-dir halt (`play.run.sh:112-116`) already refuses
  the same shape with the reason "an empty set would report as a pass"
- rework: clean — one guard; drop it and the run behaves as today
- confidence 85%: the wish does not ask for it; it is a scouts-honor fix in the branch the wish
  touches, and changes an exit code a caller could depend on (none found in this repo)
- where: `play.run.sh` `--all` branch, before the stamp claim
- verdict: CONFIRMED by director, 2026-11-06 — an empty index halts with exit 2
