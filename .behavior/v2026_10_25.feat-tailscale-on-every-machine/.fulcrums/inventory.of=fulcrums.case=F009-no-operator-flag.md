# F009 — `--operator` dropped; the join runs as `sudo tailscale up`

- **fork:** `--operator=$USER` (the user drives tailscale without sudo) · no operator (root joins once)
- **taken, why:** no source asked for it; the join needs root once and the run holds `sudo -v`; `tailscale status`, which verify reads, needs no root — the narrower grant
- **rework:** clean — one flag
- **confidence 85%, why low:** the commander may want `tailscale up/down` without sudo for daily use; not asked
- **where:** vision `.the contract` §2
