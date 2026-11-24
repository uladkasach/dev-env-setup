# F13 — on a pts, a keystroke holds the box; output alone does not

## .the fork
- **output holds (the old check)** — read a pts's mtime. a plain ssh shell that streams a long job,
  with no tmux and no brain trace, holds the box while it prints
- **a keystroke holds (this change)** — read a pts's atime. a redrawn status clock in an attached
  client no longer holds an idle box awake forever

## .taken — a keystroke holds
- the old rule pins a box awake on any attached client that redraws — a status line, a clock, a
  `watch` — so an idle grove bills for as long as a laptop stays connected
- every fleet crew writes a brain trace, and every duct is read by its own pane output, so the
  crew-at-work case the wish names is held by those two signals, never by a pts
- the case the new rule drops is a human's bare ssh shell that only prints, for 3h, with no keystroke
  and no duct. it is the one real loss, and the PR names it

## .rework — clean
one predicate in `read_pts` (`%A@` → `%T@`), and the `keystroke` / `output` arms swap.

## .confidence — 65%, and why it is low
it changes a behavior the wish never named, and the vision calls the pts signal unchanged. the
kernel's atime stamp on a real keystroke is still owed a measure (F10).

## .where
`idle-hibernate.sh` `read_pts`; arms `keystroke`, `output`, `ptmx`

## .verdict
open — a wisher call, flagged in the PR
