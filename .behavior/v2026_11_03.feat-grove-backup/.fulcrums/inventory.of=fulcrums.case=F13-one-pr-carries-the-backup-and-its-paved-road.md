# F13 — one pr carries the backup and the road it was proven over

## .the fork

pr #192 holds the backup (`5.26.backup`, `grove.backup.*`) and the work that let it be proven
on a live grove: `git.grove.provision boot --what`, `file.exec.set`, `git.tree.aside`, the
`play.stop` / `play.await` pair, `git grove sync` and `list`, `network.tailnet.peers.get`,
`aws.reach --gitroot`, and shell fixes the boot met. a peer (i004 r011 blocker.4) asked for three
prs: tools, shell and forest, backup.

- **A** — one pr. each change rides with the backup that needed it, and is clamped by a play
- **B** — split into three prs now, the backup last
- **C** — split later, after the backup merges

## .taken: A

- each non-backup change is a defect or an absent tool the backup's own proof met on a live grove,
  fixed at the moment it bit (`rule.forbid.deferred-provision-defects`, `rule.forbid.adhoc-shell`).
  none is a feature the wish did not need
- every one is clamped by a staged play, and the boot clamps
  (`prove.boot-steps-name-each-verdict`, `prove.small-skills-snap-what-a-human-reads`) cover the
  seams between them
- the backup cannot merge before its tools: `boot --what` is how its bundle reaches a grove, and
  the round trip's proof on hetzner ran through it. a split puts the backup pr behind two others
  for no change in what ships
- the renumbers (5.24 → 5.25 → 5.26) came from new bundles on main, never from this mix

## .rework — dirty

a split rewrites a branch of ~40 commits that mix the concerns, re-runs each pr's proof, and
re-reviews each. no caller hardens against A, so it is a branch surgery, not a teardown.

## .confidence — 70%

the scope of a pr is the wisher's call. A is the best guess for the wish's urgency (p0, asap).

## .risk — safe

no credential or prod write turns on the shape of the pr. the one risky change in the set,
`git grove sync`'s host key read, is its own fulcrum (F10).

## .where

pr #192 as a whole; disputed at i004 r011 blocker.4
