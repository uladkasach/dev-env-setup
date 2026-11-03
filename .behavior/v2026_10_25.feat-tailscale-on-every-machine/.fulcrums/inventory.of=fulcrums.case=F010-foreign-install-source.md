# F010 — a hand-installed tailscale still gets the signed source

- **fork:** binary present → no work at all (the gh pattern) · binary present → still declare the signed source so `apt upgrade` reaches it
- **taken, why:** the commander settled currency as a manual `apt upgrade` (q6); a box with no signed source cannot upgrade through it
- **rework:** clean — one branch in the upsert
- **confidence 60%, why low:** it diverges from `5.4.gh`'s "present → no work" shape; a snap or static install would hold two sources
- **where:** inventory row "present from another source"
