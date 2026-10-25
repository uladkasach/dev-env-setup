# F18 — the clamp play is this pr's test surface; no skill snapshot harness is built here

## .the fork

5.3 peers (r2 b1, r3 b2, r4 b1, r4 b2) ask for an acceptance test and a `.snap` for the new
`rhx play.run --resnap` flag, and for the 5.3.brains verify output.

- **taken**: hold. the verify output is covered: every ✋ a human reads is pinned whole in the clamp
  (`pinned()`: 2k, 8p, 15b, 22d, 22e, 22j and others) and arm 23 pins the whole apply-and-verify
  report to `.seam.snap`. `--resnap` is one line that exports `GROVE_RESNAP=1`; its one consumer,
  arm 23, was run with it and without it, and a tampered baseline went red
- **rejected**: build a snapshot harness for `.agent/repo=.this/role=any/skills/*`. none exists for
  any skill flag in this repo (`play.run`'s `--play`, `--list`, `--within` have none); to build one
  is a new test layer, out of this wish's scope

## .rework

clean — a harness, once it exists, adds a case for `--resnap` without a change to the flag.

## .confidence

75% — the flag is small and proven by use; the gap is the harness, not the flag.
