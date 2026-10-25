# F19 — r1 (5.3, i001) reviewed a spliced copy of the upsert; the real file holds neither defect

## .the fork

r1 blocker.1 reads `configure.upsert.sh` as cut off mid-function with a `+` diff hunk spliced in;
blocker.2 reads that hunk as a second home for the lock declaration. nitpick.10 reads `--resnap`
as unimplemented.

- **taken**: dispute, on measured evidence
  - `rhx shell.syntax.verify --path src/grove.provision/5.devtools/5.3.brains` → `all 5 files parse ✔`
  - `_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=`, both mode constants, `lock_declared` and
    `arrow_target` match only in `_.sh` (lines 513, 519, 520, 524, 545) — one home
  - `--resnap` is in `.agent/repo=.this/role=any/skills/play.run.sh` (parse branch, usage, error
    line); the reviewer's scope (`**/*.{ts,sh,md,snap}` intersect since-main) read the play, not
    every file it reached
- **rejected**: edit the upsert to satisfy a view of it that is not the file

the same splice shape was reported once before (5.1 i004 r1 nitpick.1), so the review input, not
the file, carries it.

## .rework

clean — no code change rides on this.

## .confidence

90% — two measured checks answer it.
