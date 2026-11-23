# F12 — the restore splits its streams by WHAT refused: the call to stderr, a unit in the tree

## .the fork

`grove.backup.restore` refuses at two scales: the call (bad args, no reach, the lock) and one unit
of a run (a present target, a manifest it cannot read). a peer asked that both land on one stream.

- **A** — a call refusal goes to stderr and no unit runs; a unit refusal is one row of the run's
  tree on stdout, beside its peers' verdicts. the header states the split
- **B** — every `✋`/`💥` row to stderr, the rest of the tree to stdout
- **C** — all of it to stdout

## .taken: A

- a unit refusal is one verdict among several in a run that goes on (`--all`). B tears one tree
  across two streams, so a reader of either stream sees a broken tree
- a call refusal ends the run before any tree exists, and stderr is where a caller looks for why a
  command never started
- the exit code carries the class on both paths: 2 on any refusal, 1 on a failure

## .rework — clean

`row` and `constraint` are the two writers. a switch is one redirect in each.

## .confidence — 85%

## .risk — safe

no data path depends on the stream; both the snap and the exit code pin the behavior.

## .where

`.agent/repo=.this/role=any/skills/grove.backup.restore.sh`, its header guarantee and `row` /
`constraint`; disputed at i003 r009 nitpick.3
