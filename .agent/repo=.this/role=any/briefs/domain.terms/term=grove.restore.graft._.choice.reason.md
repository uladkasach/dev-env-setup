# domain.term.choice.reason: grove.restore.graft

## .etymology

a gardener's graft joins a cut branch onto a live tree, and the tree keeps its own growth. that is
the act: the old grove's branches join the new clone, and no live branch is cut back. the word
also fits this repo's tree vocabulary (`term=grove`, `term=tree`).

chosen over:
- `merge` — git's own word for a commit that joins two histories. a graft never writes a merge
  commit: it only fast-forwards or lands aside. to reuse `merge` would overload one word onto two
  acts
- `overwrite` — the act a graft exists to forbid
- `sync` — implies both sides end equal. a graft leaves a newer live branch ahead

## .disputes
none yet.

## .evidence

the five cases `graft_ref` handles:

| live clone | backup | the graft |
|---|---|---|
| no such branch | has it | lands as-is |
| equal | equal | no change |
| ahead | behind | stays |
| behind | ahead | fast-forwards (ff-only on a clean checkout; aside on a dirty one) |
| diverged | diverged | lands aside as `<grove>/<branch>` |

a stash entry or a worktree's detached HEAD always lands aside, under `<grove>/stash` or
`<grove>/wt/<dir>`.

## .invariants

- a graft never moves a live ref backward and never writes a merge commit
- a graft deletes its own hidden `refs/grove-backup/*` after the fetch
