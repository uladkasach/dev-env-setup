# F15 — `--all` lays every unit the grove ever landed; a unit is never retired

## .the fork

a unit's objects stay in the bucket after its tree is deleted, so `--all` lays every tree the dead
grove ever held. peers asked for a retire (i004 r011 nitpick.6: a `live.json` of the units each ✓
pass saw), a per-tree read (i004 r010 nitpick, the vision's o8), and a preview or subset for `--all`.

- **A** — `--all` lays every unit; `--from <grove> --list` is the preview, dated per unit; one unit
  is named by its own flags
- **B** — each ✓ pass writes the live unit set; `--all` lays that set, and the list marks the rest
- **C** — B, plus a per-tree status read on the live box

## .taken: A

- a tree the crew deleted on purpose costs a fresh grove one dir. a tree a retire wrongly drops is
  work lost. a dead grove is read once, by a human, so the cheap mistake is the one to keep
- `--from <grove> --list` already names each unit with its latest date and class, before a lay;
  each unit has its own restore flags, so a subset is a list of calls
- the live set of B would be a second record of what the walk sees, written by the pass that
  died. a pass cut short by the death writes a stale set, and `--all` would then skip the newest
  trees, the ones most likely unpushed
- the bucket's lifecycle rules are infra's (#63); a retire here would race them

## .rework — clean

B is one write at the end of a ✓ pass and one filter in `--all`; no reader hardens against A.

## .confidence — 75%

## .risk — safe

A lays more, never less. no credential or prod write turns on it.

## .where

`grove.backup.restore --all`, `grove.backup.get --from <grove> --list`; disputed at i004 r011
nitpick.6 and i004 r010 (o8, the `--all` preview)
