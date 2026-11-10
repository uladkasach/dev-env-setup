# domain.term: backup

term.chosen   = grove.backup
term.kind     = noun          # also the verb: the agent backs up a grove
term.boundary = grove
term.synonyms.forbidden:
- snapshot      (a read-only map for a human; see `term=snapshot`)
- park          (see `term=park`)
- archive
- sync
- mirror

## .what
a redundant copy of a grove's `~/git`, `~/.claude`, and `~/.rhachet`, kept in the camp bucket,
that a machine restores onto a fresh grove.

## .refs
- src/grove.provision/5.devtools/5.24.backup/                       # the bundle, the agent, its timer
- .agent/repo=.this/role=any/skills/grove.backup.get.sh             # the status line, every grove, one grove's units
- .agent/repo=.this/role=any/skills/grove.backup.restore.sh         # its mirror: `term=grove.restore`
- .play/permanent/prove.grove-backup-round-trip.play.sh

## .reason
- `term=grove.backup._.choice.reason.md`
