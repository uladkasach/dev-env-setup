# domain.term.choice.reason: grove.backup.unit

## .etymology

a unit is the smallest whole the backup moves: the agent puts it, skips it, or retries it as one;
a restore lays it as one. `unit` says "one whole of a set", which is the sense.

the boundary is `grove.backup`, so it never meets the systemd unit the bundle installs
(`grove-backup.service`) in a contract. a comment about the systemd one says "systemd unit".

chosen over:
- `chunk` / `shard` / `part` — each names a fragment of a larger whole. a unit is whole on its
  own: one clone restores with no other unit present
- `object` — the s3 word for the container that HOLDS a unit. one unit holds one object per date;
  the two stay apart, so a reader can tell the content from its container

## .disputes
none yet.

## .evidence

enumerated before the word was picked (`rule.require.enumerate-before-you-name`):

| kind | key tail | restored by |
|---|---|---|
| clone | `org=<o>/repo=<r>/tree=<r>/date=…` | graft (`term=grove.restore.graft`) |
| worktree | `org=<o>/repo=<r>/tree=<dir>/date=…` | lay, then `git worktree repair` |
| home | `home=<dir>/date=…` | lay only absent files |

`unit` covers all three rows and excludes its neighbours: a whole grove is the backup; a lone
file is no unit.

## .invariants

- a unit is put only when its sha256 (of the uncompressed bytes) differs from its latest object
- a unit's key names its grove and its seat, so two groves never write one key
