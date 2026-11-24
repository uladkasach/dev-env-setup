# F17 — a trace-root glob that a denial truncates mid-expansion is not guarded

## .the fork
- **guard it** — expand each root a second way (a `find` over each glob segment) and compare, so a
  dir the expansion skipped on EACCES is loud
- **leave it** — bash's glob expansion drops an unreadable dir in silence, and the check accepts that

## .taken — leave it
- the unit runs as root, and root reads through every DAC bit (`CAP_DAC_READ_SEARCH`), so a 0700
  home or clone dir expands. the `refused` and `freshunread` arms prove the walk stays loud when a
  dir below the expansion refuses
- what remains is a denial root itself meets: a root-squash nfs home, or an LSM policy. a cloud
  grove's homes sit on its own ebs volume, with no LSM policy over them
- a second expansion doubles the walk's syscalls on a box measured at 6000+ traces, to guard a
  shape no grove holds

## .rework — clean
add the second expansion inside `walk`, plus a clamp arm that denies a parent dir. no contract moves.

## .confidence — 85%, and why it is not higher
a future grove could mount homes over nfs; F16's unit bounds, if taken with the wrong capability
set, would create exactly this shape. that change owes this guard.

## .where
`src/grove.provision/1.system/1.15.hibernate/idle-hibernate.sh` — `walk`

## .verdict
open — best-guessed at 5.1
