# F5 — the shared grove `ask` and registry-field lift waits for its own pr

## .the fork

peer round i004 (r011 nitpick.5) finds the bounded remote read (`timeout -k`, `BatchMode`,
`bash -lc %q`, `__duct_strip_escapes`) held in three skills — `git.grove.auth.github.set`
(two variants), `git.grove.auth.keys.set`, and now `git.grove.auth.commit.set` — and the registry
field read held in `grove_ssh_seat_ready`, `git.grove.seat.get`, and this skill. it asks for one
`grove_ssh_ask` and one `grove_registry_field` in `git.grove.ssh.operations.sh`.

| option | for | against |
|---|---|---|
| lift now | one holder of each road | touches two skills outside this route, each with its own clamps and live behavior; a regression there would ride a commit-gate fix |
| lift in its own pr (taken) | each consumer is proven on its own; this pr stays the commit gate | three holders stand until then |

## .taken, and why

defer, with a caught dream (`v2026_11_21.refactor.grove-ssh-ask-one-holder`). the lift is
real work across files this route does not own — it fails CLEAN
(`rule.always.fix-forward-under-scouts-honor`). the one holder this route COULD remove without a
ripple, it did: the open-hours path is now read from 5.18's own `GROVE_OPENHOURS_CWD`.

## .rework

clean: the skill swaps `_ask_said` / `_registry_field` for the shared calls when they land.

## .confidence — 85%

## .where

`.agent/repo=.this/role=any/skills/git.grove.auth.commit.set.sh` · `git.grove.ssh.operations.sh`

## .verdict

open — for the council.
