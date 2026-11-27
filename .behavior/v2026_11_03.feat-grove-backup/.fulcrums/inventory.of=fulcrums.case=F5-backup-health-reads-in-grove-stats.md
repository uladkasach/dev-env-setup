# F5 — where backup health is read

## .the fork

#169 asks for "a backup line in grove stats". that surface exists, in `ahbode/infrastructure`:
`rhx git.grove.stats --box <name>` (`.agent/repo=.this/role=any/skills/git.grove.stats.sh`), the
first read when a grove misbehaves (`howto.tend-groves.md:380`). it already reads the box over ssm.
infra's own vision took this path (its F5: "journal + status file + a `git.grove.stats` link").

this repo owns the status file; infra owns the stats skill.

- **A (taken)** — this repo writes `/var/lib/grove-backup/status.json` (a stable contract: `at`,
  `verdict`, counts, cause) and renders it in two places it owns: the bundle's `provision.verify`
  and `rhx grove.backup.get`. infra's `git.grove.stats` renders a `backup:` line from the same file —
  an item owed by infra, named in the pr body
- **B** — this repo also adds a sixth rung to `git.grove.ready.verify`
- **C** — skip `git.grove.stats`; the bundle verify is enough

## .why A

- `git.grove.stats` is where a commander already looks; a verify line on the box is read only by
  whoever runs a plan there, which is nobody, routinely
- the status file is the seam: one writer (the agent), many readers, each in its own repo
- C leaves a failed backup unseen until someone thinks to plan the box — the silent stop the wish
  forbids

⚠️ `git.grove.stats` reads ec2 via ssm. a hetzner grove has no ssm; its read is infra's
`hetzner.grove.probe` (infra#64). so the hetzner backup line is owed there.

## .risk — safe

- the status file holds counts, a verdict, a cause, and a time — never a key or a secret
- infra's renderer reads it over the ssm reach `git.grove.stats` already holds; no credential is
  added. the only write is a local file under `/var/lib/grove-backup/`, not a prod resource

## .rework — clean

the status file's shape is the one contract; renderers are thin.

## .confidence — 80%

## .verdict

—
