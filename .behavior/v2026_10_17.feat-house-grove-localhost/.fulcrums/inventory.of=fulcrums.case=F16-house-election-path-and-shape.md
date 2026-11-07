# F16 — the house election: `/etc/grove/house.d/<grove>`, two words a line

## .the fork
- **A** one election file per house grove at `/etc/grove/house.d/<grove>`, root:root 0644,
  one `camper <unix user>` / `ground <unix user>` line per seat. the probe reads `id -un`
  against it
- **B** a single `/etc/grove/house` marker that names no user; any login on a box with it
  reads `house@unix`
- **C** a structured file (yaml) per grove

## .taken: A, and why at the time
- B would make the HUMAN's own login on the laptop read `house@unix` and shut every gate a
  human at a keyboard needs. the marker must name the seats, so the human is never one
- C needs a parser before node or yq exists on a fresh box; two words a line parse in awk
  with no grammar to typo (`5.18.openhours` makes the same argument for a presence flag)
- one file per grove lets a second house grove land beside the first, and lets `del` remove
  exactly one
- `/etc/grove/` is a fresh dir with no other tenant here, so the path collides with naught

## .rework
clean now. dirty once the host bundle writes it and a minted grove reads it: a move then
needs a migration of every minted election.

## .confidence 80% — why not higher
- the dir name and depth were chosen at the keyboard, not by any extant precedent for a
  root-owned grove fact in this repo
- the host bundle that writes it rests on F3 (held), so the writer side is unproven

## .where
`src/grove.env.sh` (`grove_env_probe_house`); clamp
`.play/permanent/prove.house-probe-reads-only-a-root-election.play.sh`; F5, F11.

## .risk: low
a marker file in `/etc` that names users. it writes no key, cert, grant, or prod account. the
probe trusts it only when root owns it and no group or other may write it, so a seat cannot
elect itself (clamp claim 2).
