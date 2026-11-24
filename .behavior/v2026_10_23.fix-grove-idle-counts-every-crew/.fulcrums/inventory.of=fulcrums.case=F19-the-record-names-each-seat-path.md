# F19 — the world-readable record names each seat's newest path

## .the fork
- **full verdict, 0644 (taken)** — `/run/idle-hibernate.last` holds `newest=trace <path>` and
  `duct <sock> <session>:<window>`, readable by every seat
- **0640 to a group** — only seats in that group read "why awake?"; a camper outside it reads naught
- **kind and age only** — `newest=trace 120s`; no seat's path is written

## .taken — full verdict, 0644
- "why is this box awake?" must answer from one read on the seat a crew runs on, and that seat is
  not root (vision case 6, F18). the path is the answer; a kind and an age do not say WHICH crew
- a grove's seats today are the human and the camper, and both run the crews the record names
- the walk now runs as each root's owner (i008), so a path in the record is one its owner could
  already see — a seat cannot plant a link that leaks a path it could not read
- what it still discloses: one seat's newest trace path and tmux session name, to the other seat

## .rework — clean
one `chmod` in `write_record`, or a format change in `bump`'s source text; the drift play's
`record` arms move with it.

## .confidence — 70%, and why it is not higher
the owner drop treats a seat as hostile, and this record treats it as a colleague. that is
consistent only while every seat on a grove is one team's. a grove that hosts a stranger's seat
wants the 0640 row.

## .where
`idle-hibernate.sh` `write_record`; arms `record`, `record.loud`, `traceowner`

## .verdict
open — needs the wisher's call: is a grove ever multi-tenant?
