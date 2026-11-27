# F1 — how the bucket name reaches a grove

## .the fork

the one source is `CAMP_GROVE_BUCKET_NAME` in `ahbode/infrastructure`
(`provision/aws.infra/account=camp/resources.s3.ts:17-20`). it is COMPUTED by `asOrgBucketName`, in
typescript, in a private repo. this repo is public, so the literal may never land here
(`rule.forbid.dox-in-public-repo`). the agent needs the literal on the box.

- **A** — infra declares the name on the box, beside `/etc/grove/platform`, which its bootstrap
  already writes (e.g. `/etc/grove/backup.bucket`), from the const itself
- **B** — infra publishes the names as a plain json beside `resources.s3.ts`, clamped equal to the
  const by a test; the bundle reads it via `rhx git.repo.get` at apply time
- **C** — the bundle evaluates the typescript module from a local infra clone
- **D** — a human fills the name once per grove

## .taken (tentatively): A

- one source stays one source: infra writes the value from the const it owns
- the box needs no read of a private repo, no node, no human
- same channel as `/etc/grove/platform` and the grove name (F4): one declaration file family
- an ec2 grove's userdata sits near its 16 KiB cap, so A on ec2 may need a path beside userdata;
  that is infra's to choose

B is the fallback if infra refuses A. C needs node + infra deps for one string. D is a typed copy,
which the wish forbids.

## .rework — dirty

A and B both need an infra change, so either is an item still owed from #63, named in the pr body.
the bundle's read is one function either way; the owed-item list differs.

## .confidence — 55%

unverified that a grove holds read access to `ahbode/infrastructure` (matters for B only).

## .risk — safe

- **no credential**: a bucket name is an identifier, not a secret. path A asks infra to write a
  plain file on a box it already provisions; this repo reads it and holds no new key
- **no prod write is decided here**: the fork picks how the name is READ. the put it aims is the
  feature's own write, under infra#63's grant, which scopes `s3:PutObject` to the grove bucket
  alone. a wrong name therefore fails `access denied`, loud, and writes naught elsewhere
- the dirt is coordination (an infra change owed either way), not exposure
- ⚠️ fallback B WOULD be risky: it needs a grove credential that reads private
  `ahbode/infrastructure`. if A is refused and B is taken, this grade must be re-cut to `risky`

## .where

`1.vision.yield.md` → open questions, q1

## .verdict

ruled **A** by the director, 2026-11-07, at the 1.vision approval.

if infra refuses A, the drive halts before B is taken: B needs a grove credential, so the switch is
the director's call, never the driver's.
