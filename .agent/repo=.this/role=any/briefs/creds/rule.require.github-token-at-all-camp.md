# rule.require.github-token-at-all-camp

## .what

every consumer of a box's github credential reads exactly one slug:

```
@all.camp.GITHUB_TOKEN
```

`--owner ehmpath`, `--org @all`, `--env camp`, `--key GITHUB_TOKEN`. no consumer
invents its own coordinates, and no consumer falls back to a different slug when
this one cannot be read.

## .why each axis is what it is

| axis | value | why |
|---|---|---|
| `--org` | `@all` | a BOX's credential belongs to no single org — see below |
| `--env` | `camp` | this repo's word for grove infrastructure |
| `--key` | `GITHUB_TOKEN` | the box's token, NOT the mechanic's commit token |
| `--owner` | `ehmpath` | every keyrack call in this repo passes it |

### ⚠️ `@all` is a REQUIREMENT, not a preference

`@this` means "the root manifest's org", so it can be composed only from a
checkout that carries `.agent/keyrack.yml`. that is fatal for the primary
consumer: git invokes a credential helper from **whatever clone the human is
standing in**, and a grove stands in many — the org code it clones, almost none
of which carries an `.agent/`. a credential under `@this` is reachable from this
one repo and no other.

`@all` is also what the credential IS. one classic pat already spans every org
its human belongs to, so to file it under one org states something false about it.

### `camp`, not `prep`

`camp` is already this repo's word for grove infrastructure — `.agent/keyrack.yml`
declares `AWS_PROFILE` there for every `git.grove.*` skill. a grove's github token
is a camp credential by that same logic.

### `GITHUB_TOKEN`, not `EHMPATHY_SEATURTLE_GITHUB_TOKEN`

those name a **different credential**. the seaturtle key is the mechanic's own commit and
push token, with its own owner and rotation. this one belongs to the BOX — what `gh` authes
with, and what a plain https `git clone` draws on.

to point a box at the mechanic's key ties a grove's reach to github to the rotation of a
robot's commit identity, so one rotation breaks the other's job.

## .the consumers — one slug, three readers

| consumer | reads it | when |
|---|---|---|
| `gh` cli | `5.4.gh/configure.upsert.sh` | once, at apply time |
| plain https git | `src/git-credential-keyrack.sh` | every fetch, at run time |
| the setter | `git.grove.auth.github.set` skill | when a human places it |

⚠️ they read the rack by different routes, so **one can be green while the other
prompts**. a human sees only "it asked me for a password" with no clue which half
is broken — which is why `prove.github-creds-from-rack` tests each separately.

## .how to set it

```sh
cd ~/git/more/dev-env-setup && rhx keyrack set \
  --owner ehmpath --key GITHUB_TOKEN \
  --org @all --env camp --vault aws.params
```

two prompts, in this order: mechanism → `1` (PERMANENT_VIA_REPLICA), then paste
the pat.

### ✔ `--vault aws.params` — shipped on purpose, and it is the ONLY vault this slug wants

a **cloud grove is exclusively ec2**, so IMDS is always there — and IMDS is the one identity
`aws.params` accepts for an `@all` slug (`asKeyrackAwsParamIdentity.js:17`). the laptop's
absence of IMDS costs this slug no capability, because a **local box is human-backed**: it
authed itself with `gh auth login` on the way past and never reads this slug at all.

so the two boxes need different things and each has what it needs. that is the design, not a
compromise:

| box | how it reaches github | why |
|---|---|---|
| cloud grove | `@all.camp.GITHUB_TOKEN` @ `aws.params` | headless — no human to answer a login; ec2 — so IMDS is always there |
| local laptop | `gh auth login`, by hand | a human is at the keyboard, so the cheapest path is the direct one |

⚠️ **do not "fix" this to `os.secure` for laptop compatibility.** `os.secure` is a REPLICA —
every grove that holds a copy holds the secret, so one rotation must reach every box, and a
box that misses it serves a stale value with no signal. `aws.params` is central: a rotation
is one write. the laptop never needed the slug, so the replica buys portability nobody uses.

⚠️ **"a rotation is one write" is true of the VALUE and false of the MANIFEST ENTRY.** measured
2026-08-10 on a fresh grove: the value sat in `aws.params`, the box's own role could read the
parameter, and every consumer still answered `absent 🫧` — because the keyrack host manifest
in that seat's `$HOME` held no entry for the slug. `keyrack init` alone does not settle it;
`initKeyrack` writes `hosts: {}`, an empty index.

so a fresh box needs the MANIFEST ENTRY placed once per `$HOME`, and the two seats (`ground`
and the camper) each need their own. **a central vault does not imply a portable read** —
`term=entry._.choice._.md` carries the four-way split behind that one word.

## 🛑 .do NOT reach for `keyrack set` to wire a manifest entry

it looks like the tool for it. it is not, and the mistake is expensive:

- `setKeyrackKeyHost.js:47` calls `adapter.set(...)` **before** it touches `hostManifest.hosts`
- `vaultAdapterAwsParams.set:153` routes `PERMANENT_VIA_REPLICA` into `setKeyrackAwsParamReplica`,
  which acquires a secret and WRITES it into SSM
- `keyrack set --help` offers no entry-only flag

⇒ **a `set` run to "just wire the entry" overwrites the live central pat.** and a `set` fed a
closed stdin stores an EMPTY value while it prints `✔ set`, so the overwrite can be a blank.

📜 this happened on 2026-08-10: this repo's own four-way table was written, and the very next
recommendation was `keyrack set --vault aws.params` — the command that destroys what the table
had just proven intact. one human question caught it.

⇒ this is the open gap under task #60. the manifest is machine state, so it wants a bundle
(`rule.forbid.repair-plays`), and no unattended command exists to write one yet.
`keyrack recipient set` writes no secret and is the candidate to measure first; it is unproven.

⚠️ **`aws.params` is NOT the app token.** a classic PAT stored centrally is still a classic
PAT — it still expires on github's clock, still needs a human to mint the next, and still
needs `--allow-dangerous`. the per-org app token and `--scope` are separate and unshipped.

### 🛑 a human's in-flight sentence states an INTENT, never a rack

the vault above is a **measurement**, read off grove-1's rack on 2026-08-05 after that
credential had served a private clone and a `gh repo list` on both orgs:

```
🔐 keyrack list
   └─ @all.camp.GITHUB_TOKEN
      ├─ mech: PERMANENT_VIA_REPLICA
      └─ vault: aws.params
```

⚠️ it is a measurement because a CLAIM was wrong here first. a human hit friction mid-set
and said *"let's use `os.secure` for now"*; this file was written to match that sentence,
and the live entry was `aws.params` the whole time — and was the one that worked.

⇒ `rule.require.trust-but-verify` covers a human's own in-flight sentence too. it says what
they INTEND; only the rack says what is stored.

**⇒ so before you follow this block, read the rack.** `keyrack list` names the vault of
every entry, is free to run, and is the one fact here that cannot go stale:

```sh
rhx keyrack list --owner ehmpath
```

phase 2's full findings, and the two consequences that will bite whoever resumes it, live in
`grove.auth.github.roadmap` under `.what a source read established`.

⚠️ **answer both at the prompts; never pipe them.** the secret prompt masks its
echo, so it reads the terminal rather than stdin. fed a pipe, `set` takes the
mechanism answer, SKIPS the secret, stores an EMPTY value, and prints `✔ set`
regardless — a blank that surfaces much later as a token github rejects.

⚠️ **there is no second `keyrack fill` step.** `set` stores the value itself;
`fill` re-drives the very same prompts, so a set-then-fill chain sends the pat
into fill's FIRST question — which asks for a mechanism — and keyrack rejects it
with `expected: "1-2"`.

## .how to read it

```sh
rhx keyrack get --owner ehmpath --key GITHUB_TOKEN \
  --org @all --env camp --unlock --allow-dangerous --value
```

- `--unlock` — a key at rest is LOCKED, and without it the get hands back no
  value at all, which reads as "no credential" forever
- `--allow-dangerous` — keyrack firewalls a long-lived classic pat through a
  replica vault (`detected github classic pat (ghp_*)`). the refusal is CORRECT;
  the flag is phase 1's debt, and phase 2's app token retires it

### ⚠️ the two rows the exit code CANNOT separate

`locked 🔒` and `absent 🫧` both exit **2** with empty stdout — only the rack's own stderr
(`status: locked 🔒` vs `status: absent 🫧`, each with its own tip) tells them apart, and they
want opposite repairs: one of which (`keyrack set`) has no entry-only mode and overwrites a
live value. a caller that keeps only the exit code has collapsed two states that need opposite
fixes. that is why five skills in this repo read stderr on this call rather than discard it.

✔ **both consumers are proven, end to end, against this one slug** — the gh cli discovery path
and the plain-https clone path, measured separately because they read the rack by different
routes. ⚠️ **a scope change does not reach `gh` on its own**: `git-credential-keyrack` asks the
rack on every fetch, `gh` holds a stored login taken once at apply time — so a re-scoped pat
reaches `git` at once and needs `rhx grove.provision --what 5.4.gh --mode apply` to reach `gh`.
that is the `entry`/`slug` split in a third costume: the stored record was correct and one
consumer's copy of it was not.

.refs = gotcha.github-token-at-all-camp.demo=rack-read-measurements, m1-m2

## 🛑 .do NOT "fix" a blocker here by a switch to `@this`

`@this` resolves from a checkout that carries `.agent/keyrack.yml`; a grove stands
in many clones that carry none. a consumer quietly repointed at `@this` would go
green while the requirement was abandoned.

📜 measured 2026-08-03: the substitution was attempted and reverted. **a tool that
passes by discard of the requirement has not passed.**

⚠️ and read a `✔ set` for exactly what it proves. it proves the STORE and says none
of the READ — two sessions read it as "the credential is placed" and were wrong both
times, at the cost of a real pat each (`term=entry`).

## .enforcement

- a consumer that reads a github credential from any slug other than
  `@all.camp.GITHUB_TOKEN` = **blocker**
- a consumer repointed off `@all` to make it answer = **blocker**
- a `✔ set` reported as "the credential is placed", with no read to back it =
  **blocker** (`rule.forbid.failhide`)
- a pat piped into `keyrack set` rather than typed at the prompt = **blocker**

## .see also

- `.agent/keyrack.yml` — where the key is DECLARED (an undeclared key reads absent forever)
- `src/git-credential-keyrack.sh` — the https git consumer
- `src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh` — the gh consumer
- `.agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh` — the setter
- `domain.terms/term=slug` / `term=entry` — the address vs the stored record
- `grove.auth.github.roadmap` — the two INDEPENDENT axes: the vault (settled) and the token
  (still a pat)

## 🛑 .`absent 🫧` collapses FOUR states, and each takes a different repair

the gate proves the read: `git.grove.provision test` clones a private repo over plain https
on every provision, so a broken credential fails it. what the gate cannot do is say WHICH
link broke — and `absent 🫧` is one word for four:

| the state | the repair |
|---|---|
| no keyrack host manifest in this seat's `$HOME` | write the manifest |
| a manifest with no entry for the slug | wire the entry |
| a lapsed session | `rhx keyrack unlock --owner ehmpath --env camp` |
| an unreadable vault | the box's role cannot read the ssm parameter |

⇒ a run that is already broken cannot diagnose itself, so a diagnose is what you REACH FOR
when the gate reddens — a scratch play under `.play/temporary/`, written to read every link
between the rack and the two consumers in one pass, and discarded after.
