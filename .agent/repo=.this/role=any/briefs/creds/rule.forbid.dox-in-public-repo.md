# rule.forbid.dox-in-public-repo

## .what

**this repo is PUBLIC.** no identifier that names a real account, host, principal, or person may
be written into it — not in code, not in a comment, not in a brief, not in an example, and not in
a scratch draft.

use a placeholder instead: `<acct>`, `<region>`, `<role>`, `<host>`, `<user>`, `<secret-arn>`.

## .why

- **it is public.** `github.com/uladkasach/dev-env-setup` is readable by anyone, and it is the
  repo a fresh machine is told to `curl` from. its readership is strangers by design.
- **an account id is a target primitive.** it is not a secret, but it turns a broad scan into a
  narrow one: it lets somebody enumerate role names, attempt cross-account `sts:AssumeRole`, probe
  a bucket namespace, or pick a phish that quotes your real infrastructure back at you.
- **git remembers.** a redaction in a later commit does not remove the earlier one. the cost of
  the first commit is permanent, so the only cheap moment is *before* the write.
- **the crawlers are automated.** account ids and arns are a known grep target across public
  github. this is not a hypothetical.

## .what counts as dox

| forbidden | use instead |
|---|---|
| an aws account id (`123456789012`) | `<acct>` |
| a full arn with a real account | `arn:aws:iam::<acct>:role/<role>` |
| a real iam role / user / profile name | `<role>`, `<profile>` |
| an instance id, vpc id, subnet id, ami id | `<instance-id>`, `<vpc-id>` |
| a private ip, a hostname, an internal dns name | `<host>` |
| a real person's email, username, or full name | `<user>` |
| an internal url (a grafana board, a broker endpoint) | `<internal-url>` |
| a bucket name, a queue name, a secret path | `<bucket>`, `<secret-arn>` |

**a secret is a different and worse category.** an api key, a token, or a private key in this repo
is not dox — it is a breach, and it needs rotation, not a redaction.

## .what does NOT count

- a public org or repo name (`ehmpathy`, `ahbode`, `uladkasach/dev-env-setup`) — these are already
  public, and to name them is the point
- a public package, tool, or vendor name
- a **term** for a resource, with no identifier: "the camp account", "the grove role". to name a
  *concept* is fine; to name its *identifier* is not

## .the test

> would this line let a stranger point a tool at a real resource?

- yes → placeholder it
- no → it is a concept, and it is fine

## .where it slips in

ranked by how often it actually happened:

1. **an example of real command output** pasted into a brief to show the shape. the shape is the
   value; the identifiers are incidental — placeholder them and the example teaches just as well.
2. **a scratch draft** — a dispatch body, a probe result, a note. written fast, reviewed loosely.
   `.temp/` is gitignored for exactly this reason, but a draft that graduates into a brief carries
   its identifiers along with it.
3. **a config comment** that explains *why* a value exists by a reference to the real resource.
4. **an error message or log** captured verbatim into documentation.

## .examples

### 👎 bad — a real account and a real principal, in an example

```sh
# 🔭 aws.whoami --env camp
#    ├─ account: 123456789012
#    └─ arn:     arn:aws:sts::123456789012:assumed-role/some-real-role/vlad
```

### 👍 good — the same example, and it teaches exactly as well

```sh
# 🔭 aws.whoami --env camp
#    ├─ account: <acct>
#    └─ arn:     arn:aws:sts::<acct>:assumed-role/<role>/<user>
```

### 👎 bad — a config comment that quotes the identifier

```yaml
# the camp account (123456789012) is where groves live
env.camp:
  - AWS_PROFILE
```

### 👍 good — the concept, not the identifier

```yaml
# the camp account is where groves live
env.camp:
  - AWS_PROFILE
```

## .the fix, when it already landed

1. **redact it now** — the exposure stops growth even though history keeps the old commit
2. **judge the history** — for an account id, a rewrite is usually not worth it; for a *secret*,
   rotate immediately and treat the rewrite as secondary
3. **find the rest** — one leak means the habit was live, so grep the whole repo for the same
   identifier before you move on

## .enforcement

- an account id, arn, instance id, private host, or real principal name in a tracked file =
  **blocker**
- a real person's email or username, outside a git author field = **blocker**
- a secret of any kind = **blocker, and rotate** — redaction alone does not settle it

## .see also

- `rule.require.repo-as-source-of-truth` — why so much lands in this repo in the first place
- `plan.grove-credentials.md` — how a machine derives secrets rather than carries them
- `git.grove.provision test` — rung 0 climbs `git.grove.ready.verify` and reports a machine's
  credential posture, one rung per credential, by name
