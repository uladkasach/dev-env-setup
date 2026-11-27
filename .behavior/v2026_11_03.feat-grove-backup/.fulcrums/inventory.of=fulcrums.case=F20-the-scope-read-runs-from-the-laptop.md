# F20 — the infra scope read runs from the laptop; the s3 contract alone needs a grove

## .the fork

a reviewer read `prove.grove-backup-scope-matches-infra` as gated on a grove, so a laptop run
would never check the scope against infra's declaration.

- **A** — hold: the play runs on the laptop and passes there; it declines only where `rhx
  git.repo.get` cannot reach the infra repo. the real s3 contract is `prove.grove-backup-live`'s,
  which needs a camp grove's credential by nature
- **B** — move the scope read into a second, laptop-only play

## .taken: A

the gate the reviewer names does not exist: the stone's laptop family run (`rhx play.run --all
--family prove.grove-backup`) read the scope play ✔, "6 passed · 1 declined · 0 failed", the one
decline `live`. B would be a copy of a play that already runs where B would.

## .rework — clean

no code depends on the play's seat.

## .confidence — 90%

measured on the laptop this stone.

## .risk — safe

no credential, no prod write.

## .where

i001 r004 nitpick.2
