# S9 — back up every 3 hours, since a dead grove is rare

## .said

oh, every 15min? thats really often. how about every 3hrs. and only if mtime moved, right?

yeah, lets do every 3 hours. i think 3hrs is fine, given the risk is so low

i.e., we expect this to pretty much never happen

## .settled

- the timer fires every 3 hours (`OnCalendar=0/3:00`), `Persistent=true` kept
- a dead grove is rare, so a 3-hour loss window is the accepted bound
- a quiet unit still skips on an unmoved fingerprint and ctime, as before
- the stale bound moves with the timer: 7 hours, two missed passes plus one

## .landed

- `grove-backup.timer`; `grove.backup.operations.sh` (stale + pass bounds)
- `howdoes.a-grove-backs-up-and-restores`; `howto.adopt-a-replacement-grove`
- `prove.grove-backup-enroll` and its snaps
- `1.vision.yield.md` q5; `5.1` and `5.3` yields; case=4
