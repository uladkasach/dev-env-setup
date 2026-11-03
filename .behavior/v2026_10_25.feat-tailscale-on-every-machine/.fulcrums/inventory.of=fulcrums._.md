# inventory.of=fulcrums — 1.vision · 5.1.execution

risk: **low|safe** = a wrong call costs only a rework in this tree · **risky** = a wrong call can
break a machine's join or a live gate.

| case | title | rework | risk | status | confidence |
|---|---|---|---|---|---|
| [F001](./inventory.of=fulcrums.case=F001-slot-2-4-under-shell.md) | bundle slot | clean | low\|safe — a slot rename moves files in this tree; no box state keys on it | **reworked** at 5.1: `5.23.tailscale`, after `5.12.rack` | 90% |
| [F002](./inventory.of=fulcrums.case=F002-member-and-tagged-not-ground.md) | contract names *member* / *tagged* joins, never `ground` | clean | low\|safe — vocabulary in prose and output only | best-guessed | 90% |
| [F003](./inventory.of=fulcrums.case=F003-cloud-verify-moon-not-hand.md) | unjoined `cloud@*` verify reads 🌙, never ✋, until #172 | clean | low\|safe — one glyph | **superseded** (S002): the tagged join lands here, so unjoined cloud verify ✋s | — |
| [F004](./inventory.of=fulcrums.case=F004-daemon-read-before-tier.md) | the join guard reads the daemon before the tier | clean | risky — a wrong order lets an `up` run on a joined node, which can reset its flags or its login | best-guessed; built as such | 85% |
| [F005](./inventory.of=fulcrums.case=F005-hetzner-probe-fact.md) | which on-disk fact the hetzner probe reads | dirty | low — no credential, no prod write | **built**: `/etc/grove/platform`; the file's bootstrap is infra's | 70% |
| [F006](./inventory.of=fulcrums.case=F006-tier-gate-audit-scope.md) | the tier-gate audit lands inside this wish | dirty | low — no credential, no prod write | **audited** at 5.1: did not grow; stays in this wish | 85% |
| [F007](./inventory.of=fulcrums.case=F007-camp-peer-source.md) | where "a known camp grove" is read from | clean | low\|safe — verify only | **built**: a peer that carries `tag:camp` | 80% |
| [F008](./inventory.of=fulcrums.case=F008-url-and-exit-mechanism.md) | how `up` prints a url and returns | clean | low\|safe — the node waits for a login, never half-joins | **built**, unmeasured: `AuthURL` + `timeout`; the first laptop apply measures it | 60% |
| [F009](./inventory.of=fulcrums.case=F009-no-operator-flag.md) | `--operator` dropped; join runs as `sudo tailscale up` | clean | low\|safe — a flag on the member `up`; a rerun can add it | best-guessed; built as such | 85% |
| [F010](./inventory.of=fulcrums.case=F010-foreign-install-source.md) | a hand-installed tailscale still gets the signed source | clean | risky — it rewrites an apt source on a box with a live client | best-guessed; built: source declared, package never reinstalled | 60% |
| [F011](./inventory.of=fulcrums.case=F011-grove-seat-guard.md) | a second guard: no member join on a box with a `camper` seat | clean | risky — it blocks the commander's own join on a laptop with a local seat | **dropped**: `grove.env.sh` refuses an unnamed box | 90% |
| [F012](./inventory.of=fulcrums.case=F012-tagged-key-vault.md) | the tagged key's slug and vault | clean | risky — a credential: a wrong slug finds no key, or hands one org's key to another's grove | **best-guessed**: per-org `ahbode.camp.TAILSCALE_AUTH_KEY`, ruled by the director 2026-10-26 · clean rework to `@all.camp` | 75% |
| [F013](./inventory.of=fulcrums.case=F013-tagged-key-by-file.md) | the tagged `up` takes the key as `--auth-key=file:…`, never in argv | clean | low\|safe — bundle-local | **built**: kb 1241 documents it; tmpfs only | 85% |
| [F014](./inventory.of=fulcrums.case=F014-preextant-aws-rack-defects-deferred.md) | pre-extant `5.6.aws` / `5.12.rack` defects deferred to their own pr | dirty | low — as live on `main` as here | **deferred**: dream caught; text-only r2 b1 fixed | 80% |
| [F015](./inventory.of=fulcrums.case=F015-peer-claims-refuted-on-evidence.md) | four peer claims refuted on evidence | clean | low\|safe | refuted | 85% |
| [F016](./inventory.of=fulcrums.case=F016-l3-points-deferred-to-the-commander.md) | l3 points deferred past 5.1; `--accept-dns` left at its default | clean | low\|safe — each lands as its own change | **ruled by the director 2026-10-29**: default `--accept-dns` kept; deferrals stand | 75% |
| [F017](./inventory.of=fulcrums.case=F017-hetzner-github-token-home.md) | where a hetzner grove's github token lives | clean | risky — a credential: a wrong vault writes a pat into a foreign account | **ruled by the director 2026-10-29**: `os.secure`; built in `5.4.gh`, clamped | 85% |
| [F019](./inventory.of=fulcrums.case=F019-live-grove-proofs-wait-on-the-first-apply.md) | live-grove proofs (hetzner read, off-ec2 token read) wait on the first apply | clean | low\|safe — evidence only; logic clamped hermetically | **open proof**, chained to `tailscale-174-first-apply` | 80% |
| [F020](./inventory.of=fulcrums.case=F020-5-3-peer-points-refuted-on-evidence.md) | 5.3 peer points refuted on evidence, or outside #174 | clean | low\|safe | refuted | 85% |
| [F021](./inventory.of=fulcrums.case=F021-proof-rule-pass-conditions-name-a-gap.md) | the proof rule's apply pass conditions admit a named gap (the sign-in) | clean | low\|safe — two brief files, no code | **for the commander**: lean (a), keep in this pr; fixed-point step restored | 70% |
| [F022](./inventory.of=fulcrums.case=F022-plays-are-unit-grain-not-acceptance.md) | the hermetic plays are unit grain, not acceptance tests | clean | low\|safe — notes only | **for the commander**: lean, grade as unit grain; inline `.mock/.why/.real` notes dreamed | 80% |
| [F018](./inventory.of=fulcrums.case=F018-preextant-play-failures-outside-174.md) | four pre-extant play failures outside #174's surface | clean | low\|safe — none is on a tailscale path | **re-ruled** 2026-11-01: out-of-pr is no reason; all four fixed in this tree | 75% |
