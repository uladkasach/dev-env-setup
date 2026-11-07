# F9 — the restore names its repo with `--of`, not `--repo`

## .the fork

the vision's contract reads `rhx grove.backup.restore --from <grove> --repo <org/repo> --tree <dir>`.
rhachet injects `--repo <registry>` into every skill it runs, so a skill flag named `--repo` reads
the registry slug (`.this`) as a repo name.

- **A** — rename the flag to `--of <org/repo>`, the name `git.grove.provision.test` took for the
  same collision
- **B** — keep `--repo`, and tell the two apart by the slash in the value

## .taken: A

- a precedent in this repo already measured the defect (2026-08-31: the injected slug landed in
  `$REPO`, and the gate tested a repo nobody named) and settled on `--of`
- B reads a value's shape to guess its author; a registry slug with a slash would defeat it

## .rework — clean

one flag name in one skill, its help, and the hints `grove.backup.get` prints. no caller yet.

## .confidence — 90%

## .risk — safe

a flag name only; it touches no credential and writes naught.

## .where

`.agent/repo=.this/role=any/skills/grove.backup.restore.sh`; vision `.the contract we propose`, row
`human surface`
