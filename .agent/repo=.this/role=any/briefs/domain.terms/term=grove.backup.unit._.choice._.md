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
one piece a grove backup puts and a restore reads whole, packed as one tarball under one key.
its kind is one of:

- `clone` · `worktree` — a tree with git state, packed self-contained
- `orphan` — a `_worktrees/<dir>` with no `.git` (`term=orphan`, sense G), packed as plain files
- `setaside` — a tree moved into its clone's git dir at `<clone>/.git/tree-del-setaside/<dir>`
  (or `_setaside/<repo>/<dir>` once restored), packed as plain files; its key's hour is cut.
  📌 no writer of that dir lives in this repo; the dir name, as found on the ec2 grove, is the
  contract the walk reads
- `home` — `~/.claude` or `~/.rhachet`, packed as plain files

## .refs
- src/grove.provision/5.devtools/5.27.backup/grove.backup.operations.sh   # grove_backup_units_walk, grove_backup_key_unit
- .agent/repo=.this/role=any/skills/grove.backup.get.sh                   # `--from <grove> --list` lists them

## .reason
- `term=grove.backup.unit._.choice.reason.md`
