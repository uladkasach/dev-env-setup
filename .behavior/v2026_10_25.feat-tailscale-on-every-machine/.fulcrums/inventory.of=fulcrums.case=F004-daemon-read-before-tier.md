# F004 — the join guard reads the daemon before the tier

- **fork:** read `BackendState` first, skip if joined · read the tier first
- **taken, why:** "one join per machine" holds on any box, joined by any path (bootstrap, #172, a hand join); a rerun of `up` with omitted flags warns rather than no-ops
- **rework:** clean — the order of two reads in one function
- **confidence 85%, why low:** with the hetzner probe in, tier-first is also safe; the order now matters only for silence on rerun
- **where:** vision invariants table
