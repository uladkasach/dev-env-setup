# hazard: a cached peer review grades the code as it was, not as it is

## .what

`route.drive` marks each peer review `cached` and stamps it with a content hash (`i003`, `i006`,
…). the hash is over the guard's `artifacts` glob. when a reviewer is `cached`, **no reviewer ran
this time** — the verdict shown is a replay of the grade given to the artifacts at that hash.

so a stone can display `approved` / `exhausted` across every reviewer while the code those
verdicts describe has since been rewritten.

## .why this is a hazard

`--as approved` reads as "a human signed off on the reviewed work". if the artifacts moved after
the grades were cached, it means "a human signed off on grades for code that no longer exists".
the trap is that the display looks identical either way — the verdicts, the blocker counts, the
tree all render the same whether the grade is fresh or a replay.

worse in the exhausted case: an exhausted reviewer carries **unresolved blockers**. those blockers
argue against the OLD implementation. approve past them after a rewrite and you have retired an
objection nobody ever re-tested, on evidence that no longer applies.

## .the tell

on 2026-08-14 the stone `5.1.execution.from_vision` showed 11/11 reviewers terminal — 8 approved,
3 exhausted — every one marked `cached` at `i003`/`i006`/`i007`. its guard globs `src/**/*`, and
`src/bash_aliases.sh` had since been substantially rewritten (a key-scheme migration, two function
renames, a new command, three deleted functions). the grades were real; their subject was gone.

## .the rule

before `--as approved`, ask: **did the artifacts change since the hash the grades were cached at?**

- artifacts unchanged → the cached verdict still describes the code; approve on it freely
- artifacts changed → the verdicts are about prior code. either
  - `--as arrived` to re-run (the hash misses, so reviewers actually read the current code), or
  - approve deliberately, aware you approve the *stone's completion*, not a review of this code

both are legitimate. what is NOT legitimate is to read a cached tree as if it graded what you are
about to ship.

## .why the cache is right to exist

this is not a defect to repair. re-review costs budget and api spend, and most stone re-visits do
not touch the artifacts — the cache is what keeps a re-drive cheap. the hazard is purely in the
READ: the display is honest (it says `cached`) and easy to skim past.

## .see also

- `rule.always.converge-to-terminal` (bhrain/driver) — terminal verdicts unlock the next level;
  this brief is about whether a terminal verdict still describes the current artifacts