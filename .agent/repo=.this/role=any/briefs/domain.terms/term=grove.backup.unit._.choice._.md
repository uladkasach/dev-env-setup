# domain.term: unit

term.chosen   = grove.backup.unit
term.kind     = noun
term.boundary = grove.backup
term.synonyms.forbidden:
- chunk
- shard
- part
- object        (allowed ONLY for the s3 object that holds one unit)

## .what
one piece a grove backup puts and a restore reads whole: a clone, a worktree, or a home dir
(`~/.claude`, `~/.rhachet`), packed as one tarball under one key.

## .refs
- src/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh   # grove_backup_units_walk, grove_backup_key_unit
- .agent/repo=.this/role=any/skills/grove.backup.get.sh                   # `--from <grove> --list` lists them

## .reason
- `term=grove.backup.unit._.choice.reason.md`
