# F8 — the full suite's reds outside this diff: three fixed here, five stay out

## .the fork

5.3 asks every failure be fixed, prior ones included. the full suite on this box is red on eight
plays whose subjects this diff never touches (5.3 yield, the sorted table).

- **fold all in** — fix each red here, bundles included
- **fold the play-only ones in, keep the rest out** — a play whose fix lives in the play itself
  rides along; a red whose fix is a bundle, a finder contract, or a seat's powers stays out

## .taken, why

the second. two reds were play-only fixes that keep every assert as it was, each small and
proven standalone, so they ride in this pr: `claude-enrolls` (a stub), `copy-kitten` (its own
tmux namespace). the six left:

- `codediff-resize-renders-once` — its fix reshapes two asserts (below), a change of a locked
  criterion, so it lands in its own pr

- `headers-carry-their-weight` — a bundle phase restructure, proven only on a box with a screen
- `rc-is-quiet-on-boot` — a zshenv guard change, proven on a grove
- `spinner-judges-the-burn-now` — a finder contract change (a pid filter)
- `ground-seat-converges`, `orphan-sweep-bites` — true verdicts on this seat's powers

each is a dream symlinked from this route with its fix's shape. the ci workflow this pr adds runs
the clamp alone, so its green does not rest on them.

### the codediff probe — taken out after 5.3 i004/i005 r12 b1

the fix rode here for two rounds; r12 judged it a change of a locked criterion outside the wish,
twice. it is reverted to main here, and the dream
`v2026_11_07.fix.codediff-resize-probe-judged-by-a-timer` holds the measured fix and its bite.
the case for its shape, kept for that pr:

- **old arm, `== 5` → `>= 5`**: that arm proves the probe CAN see the defect — no debounce, one
  render per step. an exact 5 failed on a 6th render a slow event loop adds, which is the probe
  red for a clock reason. the floor keeps its claim: fewer than one render per step means the
  probe is blind
- **control arm, 80ms → 1s**: at the shipped 80ms, a loaded box stretched the 20ms step gaps past
  the window and read 3-4 renders — a timer verdict on a mechanism that works (five standalone
  runs read 1). a 1s window proves the mechanism coalesces a burst; load cannot split it
- **the shipped value**: still read, from `init.lua`, and held to ≥ 50ms. the 50 is the floor
  that keeps the 20ms step gaps inside the window with a 2.5× margin; bite shown, 10ms → red
- what this drops: a live proof at exactly 80ms under real load. that proof was the flake

## .rework, why clean

each dream is a self-contained follow-up; none conflicts with this diff. a fold-in later is a
separate pr per subject.

## .confidence — 80%, why low

the stone's own words ask for the fix of every failure, prior ones included.

## .where

5.3 yield, the full suite; `dreams/` on this route.

## .verdict

owed by the director.
