# F3 — the ground apply re-arms a timer a human stopped

## .the fork
- **arm** — the upsert runs `systemctl enable --now idle-hibernate.timer`; the verify demands it active
- **respect a hold** — the upsert enables at boot but leaves a runtime stop alone; the verify reports a held timer as `🌙`

## .taken — arm
the wish orders the fix to retire the hand stop; one apply must leave the box converged
(`rule.require.one-command-provision`).

## .rework — clean
drop `--now`, and grade the stopped state `🌙` in the verify.

## .confidence — 70%, and why it is low
a future deliberate hold (a keepalive) is undone by the next ground apply. the keepalive skill the
wish names does not link here, so its contract is unverified.

## .where
`configure.upsert.sh`, `configure.verify.sh` of `1.15.hibernate`.

## .scope, as built
the same call reaches a masked timer: a mask is a hand hold too, and `enable --now` errors on one. so
the upsert unmasks it, and names each undo on its own line (`unmasked … a hand hold is undone`,
`re-armed — it was <state>; a hand stop is undone`). it retires every drop-in systemd loaded on
either unit, read from `DropInPaths`. the rework stays clean: drop the unmask with `--now`.

## .verdict
approved — director ahbode-ktlo, 2026-10-23: the call is clean
