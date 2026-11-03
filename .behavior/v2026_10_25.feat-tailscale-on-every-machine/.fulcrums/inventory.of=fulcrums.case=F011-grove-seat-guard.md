# F011 — a second guard: no member join on a box with a `camper` seat

- **fork:** tier alone guards the member join · tier + "no grove seat pair on this box" · tier + the absent probe fact treated as "unknown, refuse"
- **taken, why:** a hetzner box whose bootstrap fact is absent reads `local@unix` (peer review i003, blocker.2); a second fact independent of the probe keeps a remote grove from a member join. every grove has a `camper` seat; a laptop should not
- **rework:** clean — one check in one upsert
- **confidence 65%, why low:** this laptop has no `/home/camper` (weak; no `getent` read). a laptop that hosts a local grove seat named `camper` would trip the guard and block the commander's own join. it changes behavior on such a laptop, so it is the commander's to veto
- **where:** dimensions C4, case 6

## .verdict — 5.1.execution, 2026-10-26

dropped. `src/grove.env.sh` already refuses a box its probe ladder cannot name (exit 2), before any bundle runs, so an unnamed remote box can never read as `local@unix`. a second guard on a `camper` seat would add the risk this row named (it blocks the commander on a laptop that hosts a local seat) and catch no case the derivation misses. case 6 [t1] now reads the probe refusal.