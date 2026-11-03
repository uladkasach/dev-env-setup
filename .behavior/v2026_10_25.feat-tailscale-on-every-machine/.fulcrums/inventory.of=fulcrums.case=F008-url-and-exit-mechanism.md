# F008 — how `up` prints a url and returns

- **fork:** `tailscale up --timeout <short>` · a backgrounded `up`, then read `AuthURL` from `tailscale status --json` · `tailscale login` if it returns early
- **taken, why:** none yet — the commander set the shape (print and exit, q3); the mechanism is a probe on a real box
- **rework:** clean — inside one upsert
- **confidence 50%, why low:** no source checked says which form returns with the url in hand; the kb page is silent on it
- **where:** vision assumptions

## .verdict — 5.1.execution, 2026-10-26

best-guessed, unmeasured: the daemon holds the login offer, so the bundle reads `AuthURL` from `tailscale status --json` first. only when none is held does it run `sudo timeout 20 tailscale up`, discard that exit code (the client waits on the browser by design), and read `AuthURL` again. it prints the url and the rerun line, then returns. 🔴 the first laptop apply is the measurement; it is a human handoff, since it needs `sudo -v` and the sign-in is his.