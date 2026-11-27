# F11 — ducts are found by socket directory; the moved guard fires only when none answers

## .the fork
- **by listener** — read every unix socket a tmux server listens on (`ss -xlpn`), so "ducts that
  exist" and "ducts read" come from one source
- **by directory, guard at zero** — sweep `/tmp/tmux-*/*`; if no socket answers and a tmux server
  runs, hold loud

## .taken — by directory, guard at zero
- every duct this fleet opens sits under `/tmp/tmux-<uid>/` (the live sweep on this box read its
  sockets there, and none elsewhere)
- `ss -xlpn` names a listener's process only for the caller's own, unless root — a camper-run proof
  could not show it, and a second discovery path is one more path to keep right
- the guard covers the move that would blind every duct at once — a fleet-wide `TMUX_TMPDIR` change

## .rework — clean
swap the glob loop for a listener read; the arms stay as they are.

## .confidence — 75%, and why it is low
one duct swept and a second on `-S /elsewhere` reads `seen=1`, and the second is invisible with no
alarm. no layout in this fleet does that today; no gate stops one.

## .where
`idle-hibernate.sh` `read_ducts`

## .verdict
open — best-guessed at 5.1
