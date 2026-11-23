# handoff: ahbode/infrastructure · grove backup isolation

📌 owned by the human; the asks of ahbode/infrastructure for the grove backup bucket.
measured against infra main's `grove-s3` grant (`provision/aws.infra/account=camp/resources.s3.ts`).

## .the bar

| # | the bar | today |
|---|---|---|
| B1 | a grove's identity reaches its own `grove=<slug>/` prefix alone | ✗ one shared role, `<bucket>/*` |
| B2 | within that prefix, camper puts and reads backups up to 90 days old | ✗ no age bound |
| B3 | past 90 days, camper is locked out; an admin alone reaches them | ✗ |
| B4 | a put replaces a key only on the day the key names; no put destroys a prior backup | ✗ a noncurrent version can be buried (keep 24, 7d) |
| B5 | camper never deletes, nor changes the bucket's own rules | ✓ no `Delete*`; not denied explicitly |
| B6 | a replacement grove reads its predecessor's prefix, read-only, to restore | ✗ only via the shared role |
| B7 | the everyday tier reads no backup; the admin tier reads all | ✗ PowerUserAccess reads, no bucket policy |

## .who owns what

**infra enforces every bar.** this repo never relies on its own conduct for a bar; it builds to the
constraints, so a box that misbehaves is stopped by the grant.

| concern | ahbode/infrastructure | dev-env-setup |
|---|---|---|
| identity per grove | issues it (role or session tag) | adds no read; uses the default chain |
| prefix scope | grant + bucket policy | puts only under its own `grove=<slug>/` |
| 90-day lock | lifecycle to an archive class; no `RestoreObject` for groves | refreshes a live unit before 90 days, so its latest stays in reach |
| same-day overwrite | versions kept, unburiable; an alert on a put to a past-day key | puts only `date=<today>` keys |
| predecessor read | declares the successor; scopes read to the old prefix | `restore --from` reads self or the declared predecessor alone |
| fleet view, archive thaw | the admin tier | `--list` reads its own prefix; names the admin command for the rest |

## .the asks

### A1 · one identity per grove (B1)

each grove's aws principal carries its slug, so one policy can scope by it:

- ec2: a role + instance profile per grove, tagged `grove=<slug>`
- hetzner: the roles-anywhere profile maps that grove's cert to its own role (or a session tag from
  the cert's CN, `aws:PrincipalTag/x509Subject/CN`)

one tag name for both, so the policy below reads `${aws:PrincipalTag/grove}`. the choice of
mechanism is infra's.

### A2 · scope the grant to the prefix (B1, B2, B5)

```
s3:PutObject, s3:GetObject   on <bucket>/grove=${aws:PrincipalTag/grove}/*
s3:ListBucket                on <bucket>, condition s3:prefix StringLike grove=${aws:PrincipalTag/grove}/*
```

- drop `s3:RestoreObject` from every grove role (it is the 90-day unlock; admin alone)
- no `GetObjectVersion`, no `Delete*`
- the `grove-archive` bucket: the same scope, or none, if no grove writes it

### A3 · a bucket policy that holds the line on its own (B1, B5, B7)

a bucket policy, so a later broad grant (PowerUserAccess, a new role) cannot widen reach:

- deny `s3:GetObject`, `s3:ListBucket` to every principal but the grove roles and the admin role
- deny a grove role any key outside `grove=${aws:PrincipalTag/grove}/` (and its declared predecessor, A6)
- deny every principal but admin: `s3:DeleteObject*`, `s3:PutBucketPolicy`, `s3:PutBucketVersioning`,
  `s3:PutLifecycleConfiguration`, `s3:PutBucketObjectLockConfiguration`

### A4 · the 90-day lock (B2, B3)

- lifecycle: a current version moves to `DEEP_ARCHIVE` (or `GLACIER`) at **90 days**, in place of 180.
  `GLACIER_IR` at 30 days stays (still instant read)
- with no `RestoreObject` (A2), a grove's `GetObject` on an archived object fails: locked out.
  `HeadObject` still answers, so the agent's skip check keeps its metadata read
- an admin thaw (`restore-object`) is the one unlock

### A5 · no put destroys a prior backup (B4)

an s3 policy cannot compare a key's date to today, so the bar holds in two parts:

- **harmless:** noncurrent versions expire by days alone, never by count, and not before 90 days
  (today: 7 days, keep 24 — a box that puts one key 25 times buries the original). object lock in
  governance mode, default retention 90 days, makes every version undeletable as well
- **loud:** an s3 event rule flags a `PutObject` whose key's `date=<YYYY-MM-DD>` is not the event's
  utc day, to whatever infra alerts on

if infra holds a strict mechanism (a validated write path), it replaces the alert.

### A6 · a replacement grove reads its predecessor (B6)

- the grove registry declares `successorOf: <old-slug>` when a grove is replaced
- the new grove's role gains `ListBucket` (prefix `grove=<old>/*`) and `GetObject` on
  `<bucket>/grove=<old>/*`; never a put
- the box carries it, beside the bucket name: `/etc/grove/backup.predecessor` holds `<old-slug>`
- the grant ends once infra retires the old grove's record

### A7 · the admin reads all, the everyday tier none (B7)

A3's deny covers the everyday tier. the admin tier holds read, list, and `restore-object` on the
whole bucket.

### A8 · purge the objects put before the credential cut

(carried from infra#63 item 7) every `date=` key older than the day the current agent landed on
each grove, scanned for credential shapes, deleted with every version. keyrack keeps credentials
off disk and husky guards assert it, so this is defense in depth.

## .what dev-env-setup ships beside it

- the agent puts only `date=<today>` keys under its own prefix, and refreshes a live unit whose
  latest object nears 90 days, so a live tree stays self-restorable
- `get --list` reads its own prefix (plus a declared predecessor); the fleet view is the admin's
- `restore --from` takes self or the declared predecessor; an archived unit is refused with the
  admin thaw command, never a camper thaw
- an AccessDenied reads as the grant's line, named, never as a fault of the box

## .how infra proves it

from a grove, as camper:

| probe | expect |
|---|---|
| put + get under its own prefix | ✓ |
| list, get, or put under another grove's prefix | AccessDenied |
| get an object past 90 days | InvalidObjectState (archived); `restore-object` AccessDenied |
| delete any key | AccessDenied |
| from the everyday tier: get any key | AccessDenied |
| replacement grove: get under its predecessor ✓, put there AccessDenied | |

infra's `aws.s3.grove.grant.prove.sh` is the natural home for these rows.
