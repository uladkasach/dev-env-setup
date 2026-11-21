# domain.term: restore

term.chosen   = grove.restore
term.kind     = verb
term.boundary = grove
term.synonyms.forbidden:
- recover
- rehydrate
- download      (see `term=grove.pull`)
- unpack        (allowed ONLY for the tar step inside a restore; see .reason)

## .what
lay a grove backup's units onto a grove, so every tree, its unpushed commits, and its clone
conversations come back whole, and no live work is overwritten.

## .refs
- .agent/repo=.this/role=any/skills/grove.backup.restore.sh
- .play/permanent/prove.grove-backup-round-trip.play.sh             # the clone, worktree, and home restores
- `term=grove.backup` — the copy it reads
- `term=grove.restore.graft` — how a clone is laid

## .reason
- `term=grove.restore._.choice.reason.md`
