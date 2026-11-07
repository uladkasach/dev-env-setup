# F2 — the human surface is `rhx grove.backup.*`, run on the box

## .the fork

- **A (taken)** — on-box skills: `rhx grove.backup.get` (status, `--list`) and
  `rhx grove.backup.restore`. a human on a laptop reaches them through the duct
  (`rhx git.grove.send <grove> --what 'rhx grove.backup.get'`)
- **B** — laptop-side `git.grove.backup.*` that ssh in
- **C** — the agent's own cli only (`grove-backup restore …`), no rhx skill

## .why A

- bytes flow grove ↔ s3, never through the laptop (#124 named this topology)
- a restore runs as the OS user who owns the target home; on-box is that user
- `rhx` is the named surface this repo hands a human; C hides from `rhx list`

## .rework — clean

a rename, or a thin `git.grove.*` wrapper over A later.

## .confidence — 80%

`restore` is not a get/set/gen/del verb. `set` reads as "overwrite", which a restore must never do.
kept as the domain's own word.

## .risk — safe

- the restore reads the bucket with the box's own extant grove credential; no new key, and none
  leaves the box. B would route bytes through the laptop's own aws session, which is why A is safer
- the restore writes only the caller's own home on the grove, never a prod resource; it never
  writes the bucket (the grant holds no delete, and a restore holds no put)

## .verdict

—
