# F15 — the provision verify may READ the meter skill; row 6 grades writes

## .the fork

peer round i005 of 5.3 (r012 blocker 1) read claim 6c's first draft — the provision verify
"names no `git.commit.uses`" — as the test's criterion, and its current form (the skill named on
exactly two lines, each the read verb `get --org`) as a loosened test. three ways out:

- **restore the draft, drop the probe** — loses the proof that the grant cwd answers the grant's
  own skill, so a cwd whose role cannot answer fails the human mid-session at their terminal
- **move the probe to `configure.verify.sh`** — the probe proves the upsert's output (the cwd the
  upsert builds), so the provision verify is its home; the configure verify grades the meter's
  verdicts, a different fact
- **state row 6's criterion as what it was always named: no phase WRITES the meter** — a read is
  pinned exactly (verb, bound, stdin, count), and every write form still reddens 6c

## .taken

the third. row 6's header reads "no phase writes the meter"; the draft's broader grep was a proxy
for that, written on this branch before the probe existed — the play is new in this diff and never
shipped. the read itself is graded at its own grain: 11g runs the pinned read verb against the real
writer, with no meter and with one, and asserts it creates none. 6a asserts an absent meter stays
absent after a verify.

in peer round i006 the criterion was amended explicitly, as that review's option 2 asks: row 6's
header now reads "no phase writes the meter; the provision verify reads it once, by the pinned read
verb", with a block that states the whole criterion, and 6c's claim text names the one owed read.

## .rework

clean: drop the probe and restore the draft grep, two files.

## .confidence

85%: the reviewer's own list of what still holds (write forms red, 6b strict, 11g real) is the
criterion row 6 states.

## .where

`.play/permanent/prove.commitorgs-reads-the-meter-as-the-gate.play.sh`, row 6, claim 6c;
`src/grove.provision/5.devtools/5.26.commitorgs/provision.verify.sh`, the read probe.

## .verdict

moot 2026-11-22 (seed S5): the grant cwd and its read probe are removed. the provision verify reads no meter skill, and row 6 of the clamp now grades the bundle's own write.
