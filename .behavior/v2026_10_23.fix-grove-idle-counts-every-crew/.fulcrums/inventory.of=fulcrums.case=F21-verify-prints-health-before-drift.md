# F21 — the verify prints the unit's health before the drift block

## .the fork
- **drift first, health after** — the order the verify had before 5.3, which the enroll
  test-intent lane asks back, since the snap's order changed with no test-side reason
- **health first, drift after** — the order the 5.3 blemish lane asked for, so the drift block's
  `⇒ now:` and `⇒ fix` lines close the block whose gaps they answer

## .taken — health first
- the blemish lane's i003 blocker named the defect: the health `✋` lines printed beneath the drift
  block's own `⇒ fix`, so the fix read as the remedy for a run fault it cannot clear (an apply
  resets the result; the next tick raises it again)
- the reason is behavioral, not cosmetic: `⇒ fix, from the ground seat: … --mode apply` under an
  `exec-condition` ✋ tells a commander an apply heals a run fault, which is false
- no assert pins order by a partial match, so the snap is the lock; its change is the owner's
  choice, and this entry records it
- two reviewers ask opposite orders, so no `.taken` can satisfy both: a fulcrum, disputed

## .rework — clean
one block moves in `configure.verify.sh`; a resnap of the drift play follows.

## .confidence — 85%, and why it is not higher
a reader who scans for drift first now reads the health lines before it; the order that serves
the fix line is the one chosen.

## .where
`src/grove.provision/1.system/1.15.hibernate/configure.verify.sh` · the drift play's snap

## .verdict
open — the driver's best guess, flagged for the council
