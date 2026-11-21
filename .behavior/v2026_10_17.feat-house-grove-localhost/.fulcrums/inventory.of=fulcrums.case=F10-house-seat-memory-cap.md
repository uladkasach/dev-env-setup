# F10 — a house seat's slice pages first, and kills only past a backstop

## .the fork
- **A** no cap; rely on the host's extant earlyoom
- **B** a hard `MemoryMax` on each house seat's `user-<uid>.slice` — the kill lands inside it
- **C** `MemoryHigh` as the lever (reclaim + swap the house slice first, so the desktop keeps its
  RAM), `MemoryMax` set well above it as a backstop only, swap left unbounded for the slice
- **D** a cap on a shared `house.slice` that every house grove's seats join

## .taken: C, and why at the time
- A is the measured failure: earlyoom can kill the session instead of the hog
  (`gotcha.earlyoom-kills-the-session-not-the-hog`), and a house crew is a second uid on the
  human's RAM
- **B was the first draft, and the self review `has-questioned-requirements` struck it.** the
  wish's own constraint: *a swap cushion carries real weight here* — on EC2, memory pressure
  kills rather than pages, measured as an earlyoom SIGTERM of a 17-hour clone, and the wish asks
  that a laptop not reproduce that by accident. a hard `MemoryMax` as the primary lever IS that
  behavior, scoped to the crew
- C pages the crew's cold memory to swap before anyone dies; the crew slows, the desktop does
  not, and a kill happens only for a true runaway
- D is cleaner for N house groves on one box, and asks a slice re-parent the bundle would own

## .rework
clean — a drop-in per seat, two values, a re-apply.

## .confidence 65% — why not higher
- both values (a share of host RAM) are guesses; the wisher's crews set what is enough
- the wish does not name a cap; this cell came from the collocation alone, at the self review.
  the wisher may judge it belongs to a later stone

## .where
case=9; case=1 `[t0]`; inventory row 43.

## .verdict — ruled 2026-10-18 by the director (seed S1): C holds, in this stone
the cap stays in this stone, at the proposed values. the metric it serves: local crews do not
freeze the desktop, and case=9 rests on it. option D (a shared `house.slice`) stays a later
call, since it only matters for N house groves on one box.

## .risk: low
a systemd slice cap on the laptop. it bounds memory, holds no key or grant, and writes no prod account. its harm if wrong is a paged or killed crew, which is availability, not exposure.