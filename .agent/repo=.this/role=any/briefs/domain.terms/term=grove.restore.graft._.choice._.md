# domain.term: graft

term.chosen   = grove.restore.graft
term.kind     = verb
term.boundary = grove.restore
term.synonyms.forbidden:
- merge         (git's word for a different act; a graft never writes a merge commit)
- overwrite
- sync

## .what
lay a backed-up clone's refs onto a live clone: a new branch lands as-is, an older live branch
fast-forwards, a newer live branch stays, and a diverged branch lands aside as `<grove>/<branch>`.

## .refs
- .agent/repo=.this/role=any/skills/grove.backup.restore.sh          # graft_ref, restore_clone_graft
- .play/permanent/prove.grove-backup-round-trip.snap/restore.clone.snap

## .reason
- `term=grove.restore.graft._.choice.reason.md`
