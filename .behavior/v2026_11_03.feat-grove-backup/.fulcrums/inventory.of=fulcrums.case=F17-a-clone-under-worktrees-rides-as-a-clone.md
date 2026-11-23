# F17 — a clone of its own under `_worktrees/` rides as a clone, laid back at `~/git/<org>/<dir>`

## .the fork

a `_worktrees/<dir>` whose `.git` is a DIR is no worktree: it is a clone a human made there, or a
`restore --into` pointed there. the walk read it as a worktree of `repo=_unlinked`, which kept only
HEAD's branch and would restore into `~/git/<org>/_unlinked`.

- **A** — ride it as a clone: every branch, its own refs, key `repo=<dir>/tree=<dir>`. the restore
  lays a clone at `~/git/<org>/<dir>`, one level up from where it sat
- **B** — ride it as an orphan: its files only, `.git` cut. its unpushed commits ride nowhere
- **C** — a new unit shape for "a clone at a worktree path", so it lays back where it sat

## .taken: A

A keeps every commit, which the wish exists to keep, with no new shape in the key grammar a
restore must read. the cost is the place: the tree comes back one level up. where a real clone of
that name already sits at `~/git/<org>/<dir>`, the two would share a key, so that one case falls to
B and the journal names the commits that ride in no unit.

## .rework — clean

C is additive: a fifth shape, read beside the four. no reader hardens against A's key, which is an
ordinary clone key.

## .confidence — 75%

the shape is rare (`git worktree add` never makes it), and the place change is visible on restore.

## .risk — safe

no credential, no prod write.

## .where

i008 r011 blocker.1, its second defect; `grove_backup_units_walk`; clamped in
`prove.grove-backup-restore-trusts-no-unit` (walk claims)
