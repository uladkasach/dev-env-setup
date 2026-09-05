# plan: grove credentials

## .what

how a grove obtains the two credentials it needs — a **github** token and an **anthropic**
key — with no long-lived secret written to the box.

## .why now

the first provisioned grove (`grove-1`) audits **clean by omission**: zero private ssh keys,
no `gh` cli, no `~/.aws`, no `~/.rhachet`, `~/.claude/.credentials.json` absent, and
`$ANTHROPIC_API_KEY` unset. every step that would have carried a secret is `local`-tagged,
so it never ran.

that is the right default, and it leaves one question open: a grove today can clone a
**public** repo anonymously and do no more. it cannot read a private repo, cannot push, and
cannot run claude.

## .the constraints (settled by the human, 2026-07-26)

1. **github creds come from the seaturtle github app, and only from it** — no PAT, no
   deploy key, no machine user. the app is the single source.
2. **the grove must not need a repo manifest.** `keyrack fill` reads
   `$org/keyrack-infra`, which is a **private repo** — so to fill from it, the grove must
   first clone it, which needs the very credential we are bootstrapping. that circle must
   not exist.
3. **keyrack should be effectively always unlocked on a grove.** a grove is unattended;
   there is no human at a keyboard to answer an unlock prompt.

## .the circle, named precisely

```
grove wants a github token
      └─► keyrack fill --env all
              └─► needs $org/keyrack-infra   (a PRIVATE repo)
                      └─► needs a github token  ◄── the circle closes here
```

any design that begins with "clone the manifest repo" cannot bootstrap a grove. the grove
needs **one** credential it can obtain with no credential at all.

## .the one credential a grove already has, free

`grove-1` carries an IAM instance role — the grove role for the camp account — readable over IMDS with
**zero delivered secrets**. it is the only credential on the box that needs no credential to
obtain, and it is revocable centrally by detachment of the role.

that makes it the natural **root of trust** for a cloud machine: every other secret should be
one the grove *derives* by presentation of this identity, never one we *place* on it.

## .the options weighed

| option | how the grove bootstraps | verdict |
|---|---|---|
| **A. aws-backed keyrack vault** | keyrack gains an `aws.secrets` vault; the grove reads its keys from secrets-manager/ssm-param via the instance role | **recommended** — no circle, no human, no secret at rest on the box |
| **B. push the encrypted manifest over the tunnel** | the age-encrypted manifest file is pushed to the grove (no repo clone); the grove's own recipient prikey decrypts it | viable interim; still needs the grove's prikey placed once |
| **C. human-forward over stdin** | a human sends the ~1h token from their own keyrack, per session | what the extant doc names; unattended groves cannot use it |
| **D. oidc remote mint** (ehmpathy/rhachet#431) | the grove presents an OIDC identity to a broker that mints the token | the right long-term shape; not yet built |
| **E. hmac remote mint** (ehmpathy/rhachet#433) | the grove signs an http rest call to a broker per `whodisio/simple-hmac-auth` | the off-aws path; one secret at rest, mints only derived tokens |
| **F. aws broker mint** (ehmpathy/rhachet#434) | the grove invokes a broker lambda over SigV4; the broker holds the master | **the recommended path for github** — protects the master AND zero secrets at rest |

A, D, E, and F are the same idea with different proofs: **the machine proves who it is, and a
broker hands back a short-lived secret.** but A is not one of the broker options — it is the
odd one out, and that difference is the whole point:

| | reads or mints | protects a master key? |
|---|---|---|
| **A** `aws.secrets` / `aws.params` | **reads** the stored value | **no** — the box holds whatever is stored |
| **F** `aws.lambda` | mints, proof = IAM role | **yes**, with zero secrets at rest |
| **E** `http.hmac` | mints, proof = hmac | yes, at the cost of one secret at rest |
| **D** oidc | mints, proof = oidc | yes — the long-term proof layer |

so **A is right only for a credential with no derived form** (an anthropic key: the value IS the
credential). for github, where a ~1h installation token is derivable from an app private key, A
would hand the box the master — see phase 3.

## .what keyrack offers today (verified, 2026-07-26)

- `keyrack set --vault os.direct|os.secure|os.daemon|os.envvar|1password` — **no aws vault**
- `keyrack set --env prod|prep|test|all|sudo|camp` and `--org @this|@all`
- `keyrack set --max-duration <ttl>` — a per-key TTL cap
- `keyrack recipient set --pubkey <age1…|ssh>` — age recipients of the host manifest
- `keyrack infra init` — inits `$org/keyrack-infra` **and a github-apps registry** (the
  seaturtle app's home)
- `keyrack fill` — reads the **repo** manifest; `--env all` is supported

### the `--org @all` nuance

`--org @all` **does** exist on `keyrack set`. but it says which org's manifest a key belongs
to — it does **not** avoid a manifest. so `--org @all` is not the answer to constraint 2. the
gap is the **vault**, not the org scope.

## .the plan

### phase 1 — unblock a grove now (option B, interim)

1. on the grove: `rhx keyrack init --owner ehmpath` — generates its recipient key
2. from a machine that can already decrypt, add the grove as a recipient:
   `rhx keyrack recipient set --pubkey <grove pubkey> --label grove-1`
3. push the age-encrypted manifest to the grove directly, over the tunnel — **no repo clone**
4. the grove decrypts with its own prikey; keys land in `os.secure`
5. install the github credential helper (see the hardening notes below)

this breaks the circle by transport, not by design: the manifest arrives as a **file** rather
than as a **clone**.

### phase 2 — the anthropic key, by vault read (option A) — filed as `ehmpathy/rhachet#432`

request `aws.secrets` / `aws.params` vaults, so a grove reads a key via the instance role:

```sh
rhx keyrack set --key ANTHROPIC_API_KEY \
  --vault aws.params --exid /ehmpathy/grove/ANTHROPIC_API_KEY --env all
```

this is the right mechanism for a credential with **no derived form** — where the value IS the
credential, as an anthropic api key or a 1yr `claude setup-token` is. `aws.params` is preferred
over `aws.secrets`: a standard `SecureString` parameter is **free** (secrets manager is
$0.40/secret/mo), paths are hierarchical so one iam grant on `/ehmpathy/grove/*` covers the set,
and `GetParametersByPath` warms several keys in one call.

⚠️ **it is the WRONG mechanism for the github app key** — see phase 3.

### phase 3 — the github token, by broker mint — filed as `ehmpathy/rhachet#434`

**the correction that phase 2 cannot make.** a vault read hands over whatever is stored. so if
the grove's role can read the seaturtle **app private key**, then a compromised grove reads the
app private key — the local mint of a 1h token is a convention the box follows, not a boundary
the box is held to. blast radius is not one 1h token; it is *mint tokens for every installation,
forever, until the key is rotated*.

the flaw is **not** the transport. it is that the box **reads** the master. the real axis is
`vault read` vs `broker mint`, orthogonal to how identity is proven:

| | **vault read** — the box reads the secret | **broker mint** — the box asks; the broker holds the master |
|---|---|---|
| proof = IAM / IMDS | `aws.secrets` / `aws.params` (#432) — reads the master ❌ | **`aws.lambda` (#434)** ✅ zero secrets at rest ✅ |
| proof = hmac | (pointless — a secret at rest AND a master read) | `http.hmac` (#433) — master safe ✅, one secret at rest ⚠️ |
| proof = oidc | — | `#431` — the long-term proof layer |

so an **`aws.lambda`** vault: the grove invokes a broker lambda over SigV4 (the aws sdk signs, so
no custom crypto), and receives a ~1h installation token. the grove's policy is
`lambda:InvokeFunctionUrl` on one function arn and read on **no secret at all**.

#### a vault is a LOCUS, not a store

the mechanism does not change when the machine changes — only where it runs:

| axis | what it answers | values |
|---|---|---|
| **mechanism** | what *produces* the credential | `EPHEMERAL_VIA_GITHUB_APP`, static, … |
| **vault** | *where/how* keyrack reaches it | `os.secure`, `aws.params`, `aws.lambda` |

```
laptop:  mechanism=EPHEMERAL_VIA_GITHUB_APP  vault=os.secure   → reads app key locally, mints locally
grove:   mechanism=EPHEMERAL_VIA_GITHUB_APP  vault=aws.lambda  → asks the broker, which runs the
                                                                 SAME mechanism (vault=aws.params)
```

**so the broker IS keyrack.** the mechanism registry is already the translation table — so there
is no bespoke broker code per key, no new response contract, and every future mechanism gains
remote reach for free. `vault` survives as the word because keyrack's extant values already span
non-stores (`os.daemon` is a process, `os.envvar` is ambient).

#### no `--exid`, because keyrack owns the resource

`aws.params` needs an `--exid` — the parameter is a resource someone else created. `aws.lambda`
does not: keyrack creates the function, so it derives the name from the same manifest entry that
declares the key. two sources of truth for one name is drift on a timer.

#### one broker per key — the reason is the EXECUTION role

not the invoke grant (that is one line either way). the execution role is what reads secrets:

| | its role reads… | a broker bug leaks… |
|---|---|---|
| **one lambda per key** | exactly ONE secret | that one secret |
| one per tier | the tier's secrets | the whole tier |

a github mint whose role cannot read the anthropic key **cannot** leak it, whatever the bug. and
N is small: a broker is needed only for a key with a **derived form**, so a static key
(anthropic) uses `aws.params` and needs none. **today N = 1.**

#### `keyrack set` does the upsert — no separate `infra apply`

`keyrack set --vault aws.lambda` upserts the function + role + policy via `declastruct-aws`
(`rule.prefer.declastruct`), idempotently, **plan by default**.

there is no useful state where a caller may *declare* a broker-backed key but not *deploy* its
broker — that state is a manifest entry that points at an absent function. a second command
exists only to be remembered, and a forgotten one leaves the dangle
(`rule.require.fewer-paths-via-idempotency`).

the iam consequence is deliberate: to `set` such a key the caller needs `lambda:CreateFunction`
+ `iam:PassRole`. **the power to declare a broker-backed key IS the power to deploy a broker**,
and it stays scoped to the vault used — `--vault os.secure` needs no aws grant. a grove's role
must lack `lambda:CreateFunction` entirely.

⚠️ *"it runs `get`, never `set`"* was the second half of that line until 2026-08-06, and a
grove disproved it. `@all.camp.GITHUB_TOKEN` went in at `--vault aws.params` **typed on the
grove itself** — a human ssh'd in, because the secret prompt reads a tty and the value must
never cross as an argument. so a grove's role does need `ssm:PutParameter`, not `GetParameter`
alone. the `lambda:CreateFunction` refusal above still stands: the point is that a grant is
scoped **per vault**, and `set` on one vault implies no power over another.

#### the circle breaks at DEPLOY time

the broker's manifest arrives by deployment, done by a principal that already had credentials.
run time clones no repo, and **the grove needs no manifest at all** — only a name, which is not a
secret. that satisfies constraint 2 more completely than phase 2 did.

### phase 4 — extend past aws — filed as `ehmpathy/rhachet#433`

an `http.hmac` vault, secured per `whodisio/simple-hmac-auth`, so a machine with **no aws
identity to sign with** — a laptop, a foreign ci runner, a box at another cloud — reaches the
**same broker** over https. one client id + secret per machine at rest, authorized to mint only
the derived token.

it is deliberately **after** #434: on aws, `aws.lambda` gives the same protection of the master
with **zero** secrets at rest, which hmac cannot. hmac's value is only the no-aws-identity case.

the off-aws door has one trap worth a note: plain ec2 does **not** issue an oidc jwt for an
arbitrary audience — that is eks/irsa and github actions, not an instance role. the ec2
equivalent is the trick hashicorp vault's aws-iam auth uses: the caller builds a **pre-signed
`sts:GetCallerIdentity` request**, and the broker executes it to learn the caller's arn from aws
itself. proven, but it is verify code we would own, so it trails the SigV4 door.

### phase 5 — converge with #431

when the oidc mint lands, `aws.secrets` and `http.hmac` become two brokers among several and
the vault shape is unchanged.

## .the two credentials, side by side

| | github | anthropic |
|---|---|---|
| source | seaturtle app installation token | api key, or a 1yr oauth token |
| max life | **~1h, hard-capped by github** | 1yr (oauth token) / no forced rotation (api key) |
| 1yr possible? | **no** — github caps installation tokens at 1h | **yes** — `claude setup-token` |
| delivery | mint from the app key, held in the vault | read from the vault |
| consumed by | git credential helper over HTTPS | `$ANTHROPIC_API_KEY`, `$CLAUDE_CODE_OAUTH_TOKEN`, or `apiKeyHelper` |

### the anthropic paths (verified 2026-07-26 against code.claude.com/docs/en/authentication)

claude-code takes a credential three ways a grove can use, in the order it reads them:

1. **`ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY`** — plain env vars. keyrack delivers either
   directly. the simplest path; a cost choice (api credit) as much as a technical one.
2. **`apiKeyHelper`** — a claude-code config key that names a command whose stdout is taken as
   the credential. the docs name its intended use exactly: *"short-lived tokens fetched from a
   vault"*. re-invoked after 5 minutes or on a 401, with the interval capped by
   `CLAUDE_CODE_API_KEY_HELPER_TTL_MS`; it warns if the command is slower than 10s. **this is
   the vault-native path** — point it at `rhx keyrack get --key ANTHROPIC_API_KEY` and the
   grove refreshes itself.
3. **`CLAUDE_CODE_OAUTH_TOKEN`** — a **one-year** oauth token, minted by `claude setup-token`.
   requires a Pro, Max, Team, or Enterprise plan. the mint command *does not save the token
   anywhere*, so it is ours to capture into a vault. two caveats: it can only make model
   requests (no Remote Control, no claude.ai connectors), and **bare mode does not read it**.

what is **not** deliverable: the subscription login in `~/.claude/.credentials.json` (mode
`0600` on linux) is refresh-token based and rewrites itself in place. keyrack can place the
file once, but it cannot own a credential that rewrites itself, so an unattended grove must
not depend on it.

**the recommendation:** hold a 1yr `CLAUDE_CODE_OAUTH_TOKEN` (or an api key) in the vault, and
reach it via `apiKeyHelper` so the grove re-reads on expiry rather than carries a copy.

## .the step tags this implies

the credential work splits across the `any` | `local` | `cloud` axis, and the cut is NOT
"ssh is local, https is cloud". it is finer than that:

| step | tag | why |
|---|---|---|
| `install_ssh` (keygen) + the paste into github | `local` | interactive, and the key is a **human's** identity |
| the yubikey ssh key load (`util.yubikey.ssh.sh`) | `local` | needs the physical key in a port |
| `install_git_credential_keyrack` (the helper file + `credential.helper`) | **`any`** | a file on PATH; a laptop with keyrack unlocked wants it too |
| `configure_git_https_insteadof` (rewrite ssh remotes → https) | **`cloud`** | on a laptop it breaks agent-forward, commit signature, and second accounts |

two conclusions worth a record:

1. **the helper is `any`, not `cloud`.** the machine-specific part is the *rewrite*, not the
   helper. to tag the helper `cloud` would deny a laptop a live https auth path for no gain.
2. **the vault is not a step at all.** which vault a key sits in is
   `keyrack set --vault aws.params`, a manifest fact — and `aws.params` reads on both machines
   (IMDS on an instance, SSO/profile on a laptop). same vault, different proof.

the ssh side is `local` for a reason stronger than "it is interactive": an ssh key on github
authenticates **you**, so a copy on a grove lets the grove act as you, and a lost grove becomes
a compromise of your github account. the yubikey path makes that structural — a key on physical
hardware cannot travel to a cloud box. this is the one rule at the bottom of this brief, applied
to the ssh key specifically.

## ⚠️ .the two auth paths are NOT interchangeable

an app installation token cannot authenticate **ssh** — github's ssh endpoint knows only
public keys registered to user accounts. so *"app tokens exclusively"* and *"clone over
ssh"* cannot both hold, and `credential.helper` is never called for an ssh remote at all.

`define.github-auth-two-paths.md` carries the full picture: the ssh/https split, why
`useHttpPath` is the per-org route, what keyrack actually does at mint time (verified
against rhachet@1.44.4), and the `--org`/`--scope` gap that blocks the helper today.

## .hardening notes on the github credential helper

the extant design puts the helper inline in gitconfig as `'!f() { … }; f'`. that should be a
**file** — `git-credential-keyrack` on PATH, so the config reads
`credential.helper = keyrack`. four reasons:

1. an inline one-liner cannot be reviewed, tested, or diffed — the same defect
   `rule.require.playbooks-over-adhoc` names
2. it must switch on git's action (`get` / `store` / `erase`, in argv). the inline version
   answers all three, so "never store" is incidental rather than structural
3. it must **fail loud**. when keyrack is locked the helper emits `password=` and git reports
   a bare "authentication failed"; it should name the unlock command instead
   (`rule.require.errors-name-the-fix`)
4. chain a memory cache after it — `credential.helper = cache --timeout=3000` — else every
   git credential request spawns node. `cache` is memory-only, so "no secret on disk" holds

two more:

- **`insteadOf --global` is wider than it reads.** it rewrites *every* ssh remote on the
  machine, which breaks agent forwarding, commit signing, and second accounts. scope it.
- **never pass a secret in argv.** argv is visible in `ps` to any user on the box. and never
  send a secret through a duct — tmux keeps scrollback, so it lands in a capturable pane and
  in `grove.snapshot` output. stdin over plain ssh is the only safe path.

## .the one rule

> the grove derives its secrets by proof of identity; it is never handed a master key.

a compromised grove must yield only a short-lived derived credential — never the seaturtle
app private key, and never a credential that outlives the box.

## .see also

- `ehmpathy/rhachet#431` — keyrack oidc remote mint (the long-term proof layer)
- `ehmpathy/rhachet#432` — keyrack `aws.secrets` / `aws.params` vaults (phase 2; **vault read**,
  so right for a static key only — its github claim is corrected by #434)
- `ehmpathy/rhachet#434` — keyrack `aws.lambda` vault (phase 3; **broker mint**, the github path)
- `ehmpathy/rhachet#433` — keyrack `http.hmac` vault (phase 4; broker mint from off-aws)
- `ahbode/infrastructure#21` — the ubuntu AMI cutover (the role/user names change with it)
- [claude-code authentication docs](https://code.claude.com/docs/en/authentication) — the
  source for `apiKeyHelper`, `CLAUDE_CODE_OAUTH_TOKEN`, and the credential read order
