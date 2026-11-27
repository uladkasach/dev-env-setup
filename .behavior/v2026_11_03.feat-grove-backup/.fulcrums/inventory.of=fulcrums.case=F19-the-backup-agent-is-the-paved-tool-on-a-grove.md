# F19 — the backup agent is the paved tool on a grove; the howto calls it, not an rhx wrapper

## .the fork

`howto.adopt-a-replacement-grove` hands two lines a human runs on the new grove:
`/usr/local/lib/grove-backup/grove-backup --adopt` and `sudo systemctl start grove-backup.service`.

- **A** — keep them: the agent is the tool this PR ships, laid and verified by `5.27.backup`, with
  its own `--help`, its words refused when unknown, and its CLI snapped (`agent.cli.snap`); the
  unit is the declared interface systemd runs it by
- **B** — wrap both in `rhx grove.backup.adopt` and `rhx grove.backup.run`

## .taken: A

`rule.forbid.adhoc-shell` forbids a raw call as a SUBSTITUTE for a skill. here the call is the
shipped tool itself: what holds the capability tomorrow is the installed, verified agent, not a
memory of a line. a wrapper would be a second door onto one act, each with its own help to keep in
step, and the pass must run as camper from the unit either way.

## .rework — clean

B is additive: two thin skills that exec the agent, and the howto lines swap. no caller hardens
against A.

## .confidence — 70%

the howto's other lines are `rhx grove.backup.*`, so the pair reads as the odd ones out; a reader
may prefer one family.

## .risk — safe

no credential, no prod write.

## .where

i001 r001 nitpick.1; `howto.adopt-a-replacement-grove.md`
