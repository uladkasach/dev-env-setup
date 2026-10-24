# F16 — a bait that never starts declines (exit 2), and a review budget top-up stands on the ledger

## .the fork

5.3 i004 r12 read two changes as weakened intent:

- **bait spawn.** in the reaper and coredump plays, a bait that never starts or never execs exits
  2 (declined), not 1 (failed)
- **the 5.1 budget.** two 5.1 review lanes went from a budget of 3 to 4

## .taken, and why at the time

- **bait spawn → 2.** the bait is a `sleep` copy the play spawns itself. if it does not run within
  5s, the seat failed to make a process, and no claim about the reaper or the collector was graded.
  a fail there charges a code defect for a world the play never built. that false red is what gets
  a play silenced. the one cause that IS a code defect, an absent reaper in the checkout, now exits 1.
- **budget 3 → 4.** this was a route act on the 5.1 stone, warranted by `"severity":"urgent"`
  concessions to both lanes on `.route/passage.jsonl` (`enroll-impl-behavior-intent` i004 blocker.2
  and .4, i005 blocker.1, i006 blocker.1; `enroll-impl-arch-defects` i006 nitpick.5). it touches no
  test.

## .rework — clean

one exit code per bait check; the budget sits in the ledger, not the code.

## .confidence — 85%

## .where

`prove.reaper-spares-an-own-scope-server.play.sh`, `prove.coredump-catches-a-crash.play.sh`, `.route/passage.jsonl`

## .verdict

open — raised by 5.3 i004 r12 (blocker.1 in part, nitpick.2) and i005 r12 (blocker.2, blocker.3), disputed here each time
