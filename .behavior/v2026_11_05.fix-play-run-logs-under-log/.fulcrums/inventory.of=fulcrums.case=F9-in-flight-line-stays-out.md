# F9 — the silent wait inside one play stays out of this pr

## .the fork

5.3's frictionless review found that `--all` names a play only when its verdict lands, so a slow
play leaves the terminal silent for minutes (main has the same gap).

- **fold it in** — before each play, a stderr line `⏳ <slug> — in flight, bound <N>s`
- **keep it out** — catch it as a dream; this pr is the receipt

## .taken, why

keep it out. the fix opens a new output channel on every `--all` run, seen by every human and
every caller, and its contract (stderr only, never in the `.stdout.log`, never gated on a tty) is
a decision the vision never put to the director. the receipt this wish delivers is unaffected: a
reader reads the file once the run ends. the dream
`v2026_11_07.feat.play-run-all-names-the-play-in-flight` holds the shape, symlinked from this route.

## .rework, why clean

additive: one `echo >&2` before each play, one clamp case. no caller depends on the current
silence.

## .confidence — 75%, why low

5.3's frictionless review says a friction found is fixed now, and this one is small.

## .where

5.3 review `has-critical-paths-frictionless`; `dreams/` on this route. its twin, a run cut by a
signal that ends on a bare `└─ verdicts` with no note (5.3 i004 r011 nitpick.7), is the same new
stderr channel at the other end of a play, and stays out with it: the cut log holds no tally, so
the reader already reads it as `fail`, and the clamp proves it is the newest log.

## .verdict

owed by the director.
