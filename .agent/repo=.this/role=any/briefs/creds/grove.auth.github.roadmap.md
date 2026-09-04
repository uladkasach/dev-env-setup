# grove.auth.github.roadmap

## .what

how a box reaches github, what is LIVE, and what is still owed. **one credential helper
serves every state** — only the rung that answers it changes.

read `define.github-auth-two-paths` first: it declares the mechanism (ssh vs https,
`useHttpPath`, what keyrack does at mint time). this file declares the SEQUENCE.

## .the invariant

```
git → credential.helper = keyrack → git-credential-keyrack → rhx keyrack get → token
```

the asset, the bundle, the config, and the verify are **identical in every phase**. what
changes is one `keyrack get` invocation inside the helper, and one `keyrack set` a human
ran once. that is the point of the shape: a phase is a property of the RACK, not of the
repo.

## 🛑 .the TWO AXES are independent — never quote a "phase" as one word

| axis | today | still owed |
|---|---|---|
| **the vault** | ✔ **`aws.params`, LIVE** | — settled |
| **the token** | a classic PAT | a per-org app token + `--scope` |

the vault moved on its own, ahead of the token that named it. so *"phase 2 shipped"* is
false, and *"the vault is phase 2"* invites a reader to think the app token came with it.
**name the axis, never the phase number.**

the vault is settled because a **cloud grove is exclusively ec2**, so IMDS — the one
identity `aws.params` accepts for an `@all` slug — is always there. a local box has no IMDS
and needs none: it is human-backed, and authed itself with `gh auth login` on the way past.

⇒ `rule.require.github-token-at-all-camp` holds the live slug and forbids a swap back to
`os.secure`. read it before you touch a vault here.

## ⚠️ the binary is not the storage

keyrack ships **inside rhachet**, so `5.3.brains` puts it on every box that gets the
brains. measured on grove-1, 2026-07-31:

```
$ which rhx
/home/camper/.local/share/pnpm/rhx     ← the COMMAND is there ✔

$ ls -la ~/.rhachet
ls: cannot access '/home/camper/.rhachet': No such file or directory   ← the STORAGE is not
```

| | what it is | who provides it |
|---|---|---|
| the **binary** | `rhx keyrack …` | `5.3.brains`, via rhachet — **already everywhere** |
| the **storage** | `~/.rhachet/keyrack/` — host manifest, recipients, the `os.secure` vault | `keyrack init` + a manifest that reaches the box |

so a grove can RUN keyrack and hold no rack to read. that gap is what the PAT hits and what
the app token is shaped to remove.

## 🛑 .the OPEN gap in every phase — the seam is on a timer

no phase below says how a grove stays unlocked, and every one needs it. measured on
grove-1, 2026-08-06:

```
02:13   a private clone over https           ✔ real refs
10:31   the same clone, rack untouched       ✋ status: locked 🔒
```

the daemon's 540m session lapsed. no value was rotated, revoked, or edited. and the
`locked 🔒` reached even the get inside `git-credential-keyrack`, **which passes `--unlock`
already** — so the helper's own unlock did not carry it.

⇒ **a credential helper git invokes on EVERY fetch cannot rest on a human who typed
recently.** a grove reaches github for as long as some session lasts, then goes quiet with
no signal, at an hour when no human is present.

### why it SHOULD be automatable, and why that is not proof

both mechanisms a grove uses need a secret the **box already holds** — an age prikey for
`os.secure`, the IMDS identity for `aws.params` — and neither is a human's to type. so
there is no evident reason `unlock` needs a prompt here.

⚠️ that is an argument, not a measurement. the question is unanswered:

> does `keyrack unlock` complete on a box with **stdin closed**, and does a get that was
> `locked 🔒` then return bytes?

ask it with `< /dev/null`. a play sent down a duct inherits the pane's tty, so an unlock
that wants a prompt would SIT there and then eat the next command sent down the duct as its
answer — a closed stdin turns that want into a visible failure rather than a hang
(`rule.forbid.tty-as-a-proxy-for-a-human`).

⚠️ and this same warm-daemon memory is what makes the gap hard to see: with the session
warm, a get answers from the daemon and never reaches the vault at all. so every probe of
this seam passes until the moment it does not — `term=probe`, hazard 4.

---

## phase 1 — the PAT ← **where we are**

### the declaration

`keyrack set` is the WHOLE act — it prompts for the value and stores it. the box credential
is `@all.camp.GITHUB_TOKEN`, and `rule.require.github-token-at-all-camp` holds its exact
set command and the two prompts.

### what the helper asks

```sh
rhx keyrack get --owner ehmpath --key GITHUB_TOKEN \
  --org @all --env camp --unlock --allow-dangerous --value
```

`--unlock` because a key at rest is locked; without it the get hands back no value at all.
`--allow-dangerous` because keyrack **refuses a classic PAT through a replica vault** —
`detected github classic pat (ghp_*)`. that refusal is correct, and the flag is this
phase's debt made visible: the app token retires both.

### ✔ why `--org @all` — a CAPABILITY, not a preference

`@this` is defined as *"the root manifest's org"*, so it cannot be built where there is no
root manifest. measured on grove-1 2026-08-03, from a git repo with no `.agent/keyrack.yml`:

```
--org @this → ✋ ConstraintError: cannot construct slug for key '…' without keyrack.yml.
                 use full slug format (org.env.KEY) or add keyrack.yml to repo.
--org @all  → ✔ @all.prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN
```

that gap decides the design. rhachet's cli demands a git repo as cwd, and a grove stands in
**many** repos — the org code it clones, none of which carries an `.agent/`. so a credential
stored under `@this` is readable from this repo alone, and `git-credential-keyrack` — which
git invokes from whatever clone the user is in — would hit that ConstraintError everywhere
else.

`@all` is also what the credential IS: one classic PAT already spans every org its human
belongs to, so it belongs to no single org.

⚠️ `plan.grove-credentials` asserts the opposite — *"`--org @all` does not avoid a manifest,
so `--org @all` is not the answer to constraint 2"*. that claim had never been executed, and
the measurement above disproves it.

### 🛑 the key must be DECLARED, or it sets and reads absent forever

a `keyrack.yml` is the declaration; the rack is the storage. an undeclared key still SETS —
keyrack prints `✔ set` — and every later get answers `status: absent 🫧`. so a swap looks
done and reads empty forever.

⚠️ this is not hypothetical: a wrong key name written here was carried verbatim into
`5.4.gh`'s configure phase and into `git.grove.auth.github.set`, so **a brief nobody re-read
propagated the defect into two mechanisms** — which is how a roadmap outranks the code it
was meant to guide.

**`--org` is a sigil axis.** a literal org is accepted at rhachet@1.45.1, but only when it
equals the manifest org — so it is `@this` spelled out, and a credential helper still cannot
name an org it does not stand in (that selector is `--scope`, still absent):

```
get --org ahbode …   ✔ composed ahbode.prep.… , reached the pat firewall
get --org whodis …   ✋ ConstraintError: org 'whodis' does not match manifest org 'ahbode'
```

**there is no `keyrack fill` step.** `fill` is for a declared key this host does not hold,
and it re-drives `set`'s prompts — so a `set && fill` chain feeds the pat into fill's
*mechanism* question and keyrack rejects it with `expected: "1-2"`.

### why no `--scope`

a PAT is **not minted**. one classic PAT already spans every org its human belongs to, so
there is no installation to translate to and no scope to narrow. this phase needs no
upstream piece.

### what it costs

| | |
|---|---|
| at rest | one ssm parameter, read through the grove's own role |
| lifetime | **permanent until revoked** — what the app token exists to end |
| blast radius | every org the human belongs to, at the PAT's own scopes |
| the one rule | ⚠️ **violated.** a PAT is a master key, not a derived credential |

phase 1 is knowingly a compromise. it is recorded as one so it is not mistaken for the
destination.

### what it unblocks, and what it does not

- **the laptop — fully.** it never reads this slug: a human is at the keyboard, so
  `gh auth login` is the cheaper path.
- **the grove — only once the STORAGE lands.** the binary is present and `~/.rhachet` may
  not be, so the helper falls to its **`GH_TOKEN` env rung** — already the documented
  interim in `5.10.repos`'s own error text.

to make the grove durable, the manifest has to arrive: `keyrack init` there, `recipient set`
here, then the age-encrypted manifest pushed over the tunnel — never through the duct
(`plan.grove-credentials`, phase 1/option B).

---

## phase 2 — the app token + `--scope github://org/<org>` ← **still owed**

### what a source read established, so it resumes informed

read from `dist/`, not from docs:

| fact | where |
|---|---|
| `@all` → identity is **IMDS only, never a profile, never ambient SSO** | `asKeyrackAwsParamIdentity.js:17` |
| an `@all` key **clears `AWS_PROFILE`** so the default chain derives the grove's own role | `asKeyrackAwsParamCredsEnv.js:8` |
| `@all` is described in-source as "the machine-wide (**grove**) org sentinel … retrievable from any repo or none" | `asKeyrackAwsParamName.js:21` |
| the param name is **autocomputed**, so `--exid` is optional | `asKeyrackAwsParamName.js:29` |
| `@` is illegal in ssm, so `@all` becomes the reserved segment `_all_` | `asKeyrackAwsParamName.js:27` |

the autocomputed name for this repo's slug:

```
/keyrack/infra/vault/aws.params/v1/ehmpath/_all_/camp/GITHUB_TOKEN
```

### ⚠️ two consequences that will bite whoever resumes it

1. because the identity is IMDS in **both** directions, a laptop cannot write this key — it
   has no IMDS. the `set` must run **on the grove**.
2. the grove's instance role must hold `ssm:PutParameter` + `ssm:GetParameter` (and
   `kms:Decrypt` for a SecureString) on `/keyrack/infra/vault/aws.params/v1/*`. that is an
   **IAM grant, never a keyrack option** — an absent grant fails at the aws call and reads
   as a vault defect to anyone who does not expect it.

### the declaration

```sh
rhx keyrack set --owner ehmpath --key GITHUB_TOKEN \
  --org @all --env camp --vault aws.params \
  --exid /ehmpathy/grove/GITHUB_APP   # mech: EPHEMERAL_VIA_GITHUB_APP
```

### what the helper asks

```sh
rhx keyrack get --owner ehmpath --key GITHUB_TOKEN \
  --org @all --env camp --unlock --scope "github://org/$org" --value
```

note the absent `--allow-dangerous`: an app token is short-lived, so keyrack's
long-lived-token firewall has no objection to raise. the flag phase 1 must pass is exactly
the debt phase 2 retires.

`$org` comes from git, via `useHttpPath` → `${path%%/*}`. one entry, scoped per request.

### 🛑 CENTRAL STORAGE IS NOT AUTOMATIC ROTATION

the call site is **identical** in both phases — the helper never learns which one it is in.
so the vault buys no difference there. what it changes is where the value physically sits,
and that is a rotation property alone:

| | `os.secure` (the road not taken) | `aws.params` (LIVE) |
|---|---|---|
| where the value sits | a vault file **on each box** | one ssm parameter |
| a PAT expiry costs | mint → `keyrack set` → re-encrypt → **push to every box** | mint → `keyrack set` **once** |
| rotation cost | **O(number of boxes)** | **O(1)** |
| the value at rest on the box | the encrypted vault file | **none** — read through per grant |

`os.secure` is a **replica**. every grove that holds a copy holds a STALE copy the moment
the PAT rotates, with no signal — the box serves the old value until somebody remembers that
box exists. with disposable groves that chore scales with how many are run. `aws.params` has
no replica, so no copy can go stale. that alone is why it was chosen.

⚠️ **and a classic PAT in `aws.params` is still a classic PAT.** it still expires on
github's clock, still needs a human to mint the next, and still needs `--allow-dangerous`.
to read "the vault shipped" as "the token re-mints itself" is the one misread this section
exists to stop.

### ❓ the open question — does the vault delete the storage bootstrap?

`keyrack.host.age` is **itself age-encrypted**, and it is what tells keyrack that the key
exists, which vault holds it, and its `exid`. so a box almost certainly still needs
`keyrack init`, a `recipient set` from a box that can already decrypt, and the manifest
pushed — regardless of vault.

| claim | verdict |
|---|---|
| no secret at rest | ✅ certain |
| central rotation, O(1) | ✅ certain |
| no provision step on the box | ❓ **unverified, and probably false** |

`aws.params` changes where the **value** comes from. it likely does not change how the box
learns the entry **exists** (`term=entry`).

an unencrypted `keyrack.host.index.json` does exist (slugs only), but whether it alone can
serve a `get` is exactly the open question — and it is what a measurement must settle before
this is called a bootstrap fix.

### why `--scope` and not one entry per org

`--scope` is the jwt model: the credential entry is one, and the request narrows it. the
alternative — `ahbode.camp.…`, `ehmpathy.camp.…`, `nheuron.camp.…` — makes the manifest grow
with the org count and puts the scope in STORAGE where it belongs in the REQUEST.

the installation id is resolved from the scope at mint time; keyrack holds the app's `appId`
+ `privateKey` and translates.

### what it costs

| | |
|---|---|
| at rest | ⚠️ **the app private key sits in ssm**, and the grove's role can read it |
| lifetime | ~1h token, cached 55m in the per-owner daemon (memory) |
| blast radius | one org per token — the scope is the boundary |
| the one rule | **partly** satisfied: derived credential ✅, but the box reads a master ⚠️ |

⚠️ **phase 2 is a vault READ, not a broker mint.** a compromised grove reads the app private
key from ssm, and from there mints tokens for every installation, forever. the 1h token is
then a convention the box follows, not a boundary it is held to.

`plan.grove-credentials` phase 3 (`aws.lambda`, `ehmpathy/rhachet#434`) is what closes that:
the broker holds the master, the grove invokes over SigV4, **zero secrets at rest**. phase 2
is the right next step and **not the terminal state**.

---

## .the ONE upstream gap phase 2 waits on

| piece | state |
|---|---|
| `keyrack get --scope` | **absent at 1.45.1** — dispatched 2026-07-31 |

⚠️ **do not keep a roster of a tool's capabilities here.** `keyrack set --vault` offers
`os.direct`, `os.secure`, `os.daemon`, `os.envvar`, `1password`, `aws.config`, `aws.params`,
`github.secrets` — and that list drifts the moment the tool ships. ask `--vault` for its own
list rather than read a table (`rule.require.trust-but-verify`).

## .what changes in this repo between the phases

**one line of the helper, and one `keyrack set` a human runs.** the bundle, the asset path,
the install target, the git config, and the verify are untouched.

that is the test of whether the shape is right: if a phase change needed a new bundle, the
helper would hold policy it should not.

## .the ladder the helper walks, in both phases

```
1. GH_TOKEN env       → set for this shell; the grove's path until the RACK lands there
2. rhx keyrack get    → phase 1: --unlock --allow-dangerous
                        phase 2: --unlock + --scope github://org/$org
3. decline            → exit 0, empty stdout, reason on stderr
```

rung 1 is deleted when the grove has storage to read. rung 2 gains `--scope` at phase 2.
rung 3 is permanent — it is what makes the helper safe to install on a box whose remotes it
does not serve.

## .see also

- `rule.require.github-token-at-all-camp` — the ONE slug, its vault, and its three consumers
- `define.github-auth-two-paths` — the mechanism, and why ssh and the helper are exclusive
- `plan.grove-credentials` — the five-phase credential plan, and the one rule
- `rule.require.security-paramount` — why a token at rest is what to avoid
