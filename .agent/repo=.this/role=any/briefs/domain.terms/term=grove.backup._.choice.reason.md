# domain.term.choice.reason: grove.backup

## .etymology

`backup` already carries one sense in this repo: a copy a MACHINE restores (`backup_env.sh`).
a grove backup is that sense, so the word is reused, not coined.

`term=snapshot` and `term=park` list `backup` as a forbidden synonym. those lists guard their own
concepts from the word: a snapshot is a map a human reads; a park sets work aside. neither list
bars the word from every concept, and both stand unchanged.

chosen over:
- `grove.vault` / `grove.keep` — fresh words for a concept the commander, infra, and #169 already
  call backup. a coinage here adds a synonym; it removes none
- `archive` — implies a cold, final copy. a grove backup is hot: the agent puts a fresh unit each
  hour that unit changes
- `sync` / `mirror` — imply two live sides kept equal. the bucket never writes back to the grove;
  only a deliberate `grove.restore` moves bytes the other way

## .disputes

### dispute: backup — raised 2026-11-03 — status: RESOLVED (backup holds)

- raised.by  = the vision stage of the grove-backup route (fulcrum F6)
- claim      = `term=snapshot` and `term=park` forbid `backup`, so a fresh word avoids the clash
- counter    = the forbid lists bar the word from THOSE concepts. this concept is the one
               `backup_env.sh` set as the word's sense: restorable by machine
- resolution = `grove.backup` names this concept. the two forbid lists stand unchanged

## .evidence

- precedent: `backup_env.sh` set the sense, a machine-restorable copy
- usage: ahbode/infrastructure#63 names its buckets for backup; #169 and #124 say backup
- narrative: a hetzner box dies; the commander asks whether its backup is fresh; a new grove
  restores from it. every step reads in the one word

## .invariants

- a backup never holds a plaintext credential: `~/.claude/.credentials.json` and the keyrack's
  `os.direct` vault are cut at the pack
- a backup runs as root, on a timer, with no hand step; a run that lands no unit is a ✗
- a backup's bucket name and grove name come from the box (`/etc/grove/`), never a literal here
