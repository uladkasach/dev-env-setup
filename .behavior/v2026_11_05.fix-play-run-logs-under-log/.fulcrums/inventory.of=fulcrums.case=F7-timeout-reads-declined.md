# F7 — a timeout, a play with no sanctioned verb, and a vanished play read as declined

## .the fork

`--play` answers exit 2 for a stub's own decline, and also for three causes that never ran a
claim to its end: a play that outlasts `--within`, a tracked play whose name carries no
sanctioned verb, and a tracked play gone from disk. `--all` reads every exit 2 as `declined`.
the tally is now the machine-read verdict, and a reader that takes `failed 0` as green shows
green for a tree where a play hung or never ran.

- **keep the fold** — vision case 3 settled `declined` as its own count; `--play`'s exit
  contract (2 = a constraint, a timeout among them) stands
- **count them failed** — `--play` returns a distinct code for each, `--all` folds them into
  `failed`, and one transformer (`as_verdict_of_exit`) serves both branches. the reader's
  three-count regex is unchanged
- **split it** — a no-verb play and a vanished play are facts about the index and the disk,
  known before the first play runs. a pre-flight refuses them before any log, as the untracked
  halt does, with one verb predicate shared by `--play` and the pre-flight; `--list` no longer
  names them. the timeout alone stays a runtime question. this adds a third halt the foreman has
  not ruled on, beside the untracked one

## .taken, why

keep the fold in this diff. it predates the diff, case 3 settled it, and the second option
changes `--play`'s published exit contract, which other callers read. the clamp now pins the
fold (fixture `unproven`, snapped: `1 passed · 3 declined · 0 failed`, rc=2), so a verdict
either way flips one visible case. the header no longer claims "a play that hangs fails"; it
states the timeout reads as exit 2.

## .rework, why clean

one transformer and one exit code in `play.run.sh`, the `unproven` case's expected line, and
its snap block. no caller here reads `--all`'s per-play codes.

## .confidence — 70%, why low

two reviewers, independently, graded the harm `urgent`: a ship report can read green over a
hung play. the case for the fold rests on scope and a settled case, not on the harm.

## .where

`play.run.sh` — the `--all` verdict `case` and the `--play` timeout tail;
`prove.play-run-all-reads-three-verdicts.play.sh` — the `unproven` case. raised again at 5.3
i004 r011 nitpick.1 (graded urgent: the cell reads green over a hung play) and nitpick.2 (each of
the three rows reads "declined or timed out").

## .verdict

owed by the director.
