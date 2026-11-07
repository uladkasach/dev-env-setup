# F8 — the skip compares against a unit's latest object, not today's

## .the fork

#169: "sha256 of the UNCOMPRESSED tar stream vs today's object metadata; equal → no put". the key
carries `date=<YYYY-MM-DD UTC>`. so at the first run of each day there is no object for today, and
every unit puts — every clone on the box, once a day, kept forever (the bucket never expires a
current object; `resources.s3.ts:59`). a fresh grove clones every org repo (`5.10.repos`), so
that is the whole of `~/git`, daily.

- **A (taken)** — compare against the unit's latest object, any date. `date=` then marks the day the
  unit last changed. an untouched clone is put once
- **B** — keep #169's rule; accept a daily full put
- **C** — drop `date=` from the key; let s3 versions hold history

## .why A

- B grows the bucket by the size of `~/git` per grove per day, forever — on a box that may hold
  dozens of pristine clones
- C loses history past the 24 newest noncurrent versions within 7d (`resources.s3.ts:125`)
- A keeps #169's key shape exactly; only the skip's comparison target moves. the latest object is
  one `ListObjectsV2` under the unit's prefix, which the grant allows

## .rework — clean

one comparison target.

## .confidence — 85%

## .risk — safe

- no credential: the extra read is one `ListObjectsV2` under the grove's own prefix, inside the
  grant the agent already holds
- no new prod write: the fork moves the skip's comparison target only. it can only REMOVE redundant
  puts; the put path and its grant are unchanged. the harm it guards against (a daily full copy of
  `~/git`) is cost, and the harm it could cause (a skipped change) is caught by the hash, which
  differs whenever the tar does

## .verdict

—
