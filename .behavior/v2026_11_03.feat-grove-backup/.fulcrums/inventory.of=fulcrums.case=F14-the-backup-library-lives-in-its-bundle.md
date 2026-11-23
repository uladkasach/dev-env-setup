# F14 — the backup library lives in its bundle dir, whole

## .the fork

`grove.backup.operations.sh` sits in `src/grove.provision/5.devtools/5.26.backup/`, beside the agent
it serves. the restore and get skills, the verify, and the plays source it by that path. a peer
(i004 r011 blocker.5) asked to move it to an ordinal-free home, split it per concern, and pair the
tree pack with the tree restore as one codec module.

- **A** — one library, in its bundle dir; the format literals declared once inside it
- **B** — move it to an ordinal-free dir the bundle installs from; split it in nine
- **C** — split it in place, keep the path

## .taken: A, with its format literals lifted

- the repo's rule is that an artifact owned by exactly one bundle lives in that bundle's dir
  (`repo.overview`, `.src/`). the library has one owner: `5.26.backup` installs it to the box
- the format had two copies of its literals; they are now one declaration
  (`GROVE_BACKUP_UNIT_VERSION`, `GROVE_BACKUP_UNIT_GIT_STATE`) that writer and reader both source
- the ordinal moved twice because main gained bundles. each move was one sedreplace, with the
  clamps to prove every reader followed. a dir off the bundle tree would be the first such in
  `src/`, and a second home for one bundle's files
- the restore sources the pack code it never calls. that costs a parse, not a behavior

## .rework — clean

a move is one dir rename and one sedreplace of the source path; a split is cut and paste behind
the same function names, which every caller already uses.

## .confidence — 75%

## .risk — safe

no data path changes; the round trip clamps every reader.

## .where

`src/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh`; disputed at i004 r011
blocker.5
