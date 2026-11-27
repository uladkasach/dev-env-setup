# F8 — the plays assert exact lines; they snap no transcript

## .the fork
- **snapshot** — store each play's transcript as a golden file and diff every run against it
- **exact-text asserts** — each line a human reads is asserted by its exact text, and each play
  prints its full transcript per arm for a vibecheck

## .taken — exact-text asserts at 5.1; transcript snaps at 5.3
- the lines a human reads carry epoch times, `idle=` counts, and temp paths. a golden file needs a
  scrub layer. the repo holds one convention for it — `brains.auth.test.sh --resnap` and its `.snap`
  files — and no play under `.play/` uses it yet
- every line the reviewer named is asserted by its exact text: `hold —`, `💥 … unreadable`,
  `└─ fix:`, the runtime's `🌙` decline, each verify block, and each `•` line of the upsert
- 5.3 owes `.snap` coverage of contract outputs, so the snaps land there, against output that 5.1's
  review has stopped to move. that is the stone the route assigns them to, not a deferral past it

## .correction — 2026-11-21
the first draft said "this repo's plays have none" of a scrub layer, and read as if the repo had
no snap convention. it does (`brains.auth.test.sh`); the plays do not. the choice stands on the
second reason alone: the snaps are 5.3's deliverable

## .the convention is main's, not `brains.auth.test.sh`'s — i009
`origin/main` carries the play snap convention this branch lacks: 33 files under
`.play/permanent/<play>.snap/<name>.snap` (`transcript.snap` in most), and a
`play.clamp.verify` skill beside them. so 5.3 rebases onto `origin/main` FIRST, then writes each
snap in that shape. the "no play under `.play/` snaps" line above was true at this branch's base
only; the choice to snap at 5.3 stands, and its convention is main's.

## .the transcripts owed at 5.3
- the ground-seat APPLY on a drifted box: `declared`, `retired the stopgap` with its `⇒ a box now
  holds on activity` line, `re-armed` — the commander's critical path — and the camper's `🌙`
  decline
- the journal's `hold —` and `sleep —` lines, with the record and sleep-record pair beside them
- a sleep record at `exit=unanswered`, under its verify note
- the verify on a converged box, a drifted box with a record, and an unhealthy box
- the plan on a pinned box under tmux's real `protocol version mismatch` text
- a sleep, then a wake's first hold: the record and the sleep record side by side
- the real-box plan on an unapplied grove: the stopgap, `exec-condition`, no record — the two
  false lines i008 found (`no sleep … since cold boot`, `the next tick writes it`) sat in it
- a plan on a box whose check is current and holds no sleep record
- a race arm: a server that exits between the count and its dial, with pgrep still populated
- each scrubbed of the fixture root, epochs, ages, and temp names
- stdout and stderr snapped apart: the `✋` lines (stderr) and the `•` lines (stdout) interleave by
  runner, so a merged capture reorders on another box

## .rework — clean
add a scrub (times → `<t>`, temp root → `<fix>`) and a golden file per play. no code under test moves.

## .confidence — 80%, and why it is low
an exact-text assert proves a line is present, never that the transcript around it reads well. a
stray extra line passes.

## .where
`.play/permanent/prove.idle-check-counts-every-crew.play.sh`, `prove.hibernate-*.play.sh`

## .verdict
open — best-guessed at 5.1
