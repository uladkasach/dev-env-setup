# howdoes.a-box-reach-an-aws-account

> the mechanism, for whoever changes it. the human's path is
> `howto.give-a-box-an-aws-account.md`; read that first if you only need to run it.

## .the question this answers

`rhx git.repo.test --what integration` is typed identically on a laptop and on
grove-1, and lands in the same aws account from both. how?

## .the chain, end to end

```
  a test file
      │  imports useKeyrack
      ▼
  useKeyrack.ts                          svc-chat, NOT ours
      │  rhx keyrack get --org ahbode --env test --key AWS_PROFILE
      ▼
  the RACK                               ahbode.test.AWS_PROFILE
      │  vault: aws.config  ⇒  the value IS a profile name
      │  → "ahbode.test.ehmpath"
      ▼
  process.env.AWS_PROFILE = "ahbode.test.ehmpath"
      │
      ▼
  aws-sdk reads ~/.aws/config for [profile ahbode.test.ehmpath]
      │
      ├── laptop:  sso_session → a cached sso token → <prep-acct>
      └── grove:   credential_source = Ec2InstanceMetadata
                        │ IMDS hands back the INSTANCE role
                        │ arn:…:<camp-acct>:role/<camp-grove-role>
                        ▼
                   sts:AssumeRole  →  arn:…:<prep-acct>:role/<prep-oidc-role>
                        │ (allowed by the OIDC role's trust policy —
                        │  `AllowGroveCampAssumeRole`, in ahbode/infrastructure)
                        ▼
                   credentials in <prep-acct>
```

⚠️ **the hop is the whole grove story.** a grove's badge lives in the **camp**
account (`<camp-acct>`). every account it touches beyond camp is reached by an
`sts:AssumeRole`, and that assume is what `credential_source` + `role_arn`
express. with no profile in play, a grove acts as camp — which is exactly the
failure this fixes:

```
User: arn:aws:sts::<camp-acct>:assumed-role/<camp-grove-role>/<instance-id>
is not authorized to perform: SNS:Publish
on resource: arn:aws:sns:us-east-1:<prep-acct>:svc-chat-test-…
```

that is not an absent grant. it is a call that **never asked for the hop**.

## .the four writers on this box's aws identity

| who | owns | artifact |
|---|---|---|
| `5.6.aws` (bundle) | `[profile ambient]` + `[default]` | `~/.aws/config`, one marker fence |
| `5.6.aws` (bundle) | an empty `~/.aws/credentials` | aws-sdk v2 opens it unconditionally |
| `2.5.zsh` (bundle) | `export AWS_PROFILE=ambient`, `AWS_SDK_LOAD_CONFIG=1` | `~/.zshenv` |
| `aws.reach.set` (skill) | one `[profile <org>.<env>.<owner>]` per org+env | `~/.aws/config`, one fence each |

⚠️ **three of the four touch `~/.aws/config`, and that is not
`rule.forbid.two-writers-on-one-artifact`.** that rule bites when two writers
can touch the same BYTES. each writer here owns a disjoint marker fence and
copies every other line through:

```ini
# devenv: begin                              ← 5.6.aws owns this fence
[profile ambient]
credential_source = Ec2InstanceMetadata
region = us-east-1

[default]
credential_source = Ec2InstanceMetadata
region = us-east-1
# devenv: end

# devenv: reach ahbode.test.ehmpath — begin  ← aws.reach.set owns this one
[profile ahbode.test.ehmpath]
role_arn = arn:aws:iam::<prep-acct>:role/<prep-oidc-role>
credential_source = Ec2InstanceMetadata
region = us-east-1
# devenv: reach ahbode.test.ehmpath — end
```

aws offers no second file for profiles, so the fence **is** the boundary. if you
add a fifth writer, give it its own fence and make it copy the rest through.

## .why `ambient` exists at all, beside the named profiles

`ambient` is the **box's own identity** — camp, no hop — and it is what
`~/.zshenv` points `AWS_PROFILE` at by default. it answers the question "who is
this box?", which a grove needs before any repo is cloned: `git.grove.*` skills,
`aws.ec2.get --env camp`, IMDS probes.

the named profiles answer a different question — "who should THIS SUITE act
as?" — and a consumer overrides `AWS_PROFILE` in-process to select one.

📜 note a live divergence, measured on grove-1 2026-08-08:

| box | `ahbode.camp.AWS_PROFILE` answers |
|---|---|
| laptop | `ahbode.camp.ehmpath` |
| grove-1 | `ambient` |

both name the camp account, so both work, and neither is broken. but they are
two names for one account, which is the shape a synonym takes before it becomes
a defect. a future pass should let a grove's camp entry be `ahbode.camp.ehmpath`
too, with `ambient` kept as the bootstrap alias `5.6.aws` writes before any org
is known.

## .the three ways this fails, and what each looks like

### 1. the body is absent

the rack answers a name; aws cannot find a profile by it.

```
The config profile (ahbode.test.ehmpath) could not be found
```

⇒ run `aws.reach.set` on that box. this is the grove's default state.

### 2. the name is absent

the profile exists; no consumer names it.

```
AWS_PROFILE not set
```
or, once `useKeyrack` runs `delete process.env.AWS_PROFILE`:
```
ConfigError: Missing region in config
```

⇒ the rack entry, or the repo's `.agent/keyrack.yml` declaration. an
**undeclared** key stores fine and reads `absent 🫧` forever
(`domain.terms/term=entry`).

### 3. both halves are right and the hop is refused

```
AccessDenied … is not authorized to perform: sts:AssumeRole
on resource: arn:aws:iam::<prep-acct>:role/<name>
```

two very different causes wear this one message:

- the role **does not exist** under that name → our defect, a typo or a guess
- the role exists and this grove is **not in its trust policy** → an infra ask

confirm the name before you write a handoff:

```sh
rhx git.repo.get lines --in ahbode/infrastructure --words 'ROLE_NAME'
```

⚠️ this is the exact hazard that cost a session on 2026-08-06: three guessed
role names, three refusals, and a near-report of "the grove has no prep access"
about a grove that had it (`rule.forbid.failhide`, `term=probe`).

### 4. every half is right and an EXPORTED `AWS_PROFILE` shadows the rack

no error at all. the suite runs, and runs as the wrong identity.

rhachet's own `KeyrackHostVault` states the rule: *"os.envvar is always checked
first in grant flow (ci passthrough)"*. so `process.env.AWS_PROFILE` **outranks
every rack entry**, for every org and every env — and a perfect rack is never
consulted.

measured on grove-1, 2026-08-08, after the profile body was written and proven:

```
rack   ahbode.test.AWS_PROFILE  = "ambient"        ← from the ENV, not the rack
profile ahbode.test.ehmpath     = …<prep-acct>:…/<prep-oidc-role>   ✔ answers
suite   all 44 refusals          = …<camp-acct>:…/<camp-grove-role>
```

the grove's rack held **one** entry (`@all.camp.GITHUB_TOKEN`) and no
`AWS_PROFILE` at all. the `ambient` came from `~/.zshenv`, which `2.5.zsh`
writes.

⚠️ **this is a live tension in our own design, not a keyrack defect.**

- `~/.zshenv` exports `AWS_PROFILE=ambient` so that a program which reads the
  variable directly finds the box's identity. that export is what fixed
  `AWS_PROFILE not set` on 2026-08-06.
- but one variable cannot serve four envs, and because `os.envvar` wins, that
  one variable defeats the per-env mechanism entirely.

✔ **resolved and shipped 2026-08-08:**

1. `export AWS_PROFILE` dropped from `~/.zshenv` — `AWS_SDK_LOAD_CONFIG=1` stays
2. the grove holds real rack entries per org+env, vault `os.direct`, so the
   box's identity is a rack fact rather than a shell fact
3. `[default]` in `~/.aws/config` — already written by `5.6.aws` — keeps a bare
   `aws` call alive with no profile named. that is the **regression clamp**, and
   `prove.grove-aws-identity-chain` asks it directly

the measurement, on grove-1, in order:

```
~/.zshenv exports no AWS_PROFILE                    ✔ the rack is not shadowed
region with NO profile named            us-east-1   ✔ the clamp holds
whoami with NO profile named            …<camp-acct>:…/<camp-grove-role>
rack ahbode.test.AWS_PROFILE            ahbode.test.ehmpath   (vault os.direct)
whoami via that profile                 …<prep-acct>:…/<prep-oidc-role>

rhx git.repo.test --what integration    19 suites, 31 passed, 0 failed ✔
```

the same command, typed the same way a laptop takes it. it read `0 of 19 suites`
two days earlier.

⚠️ the vault matters per box. `aws.config` unlocks by **browser sso**, which a
grove does not have: `keyrack set --vault aws.config` on grove-1 prompted
`which sso domain? / sso start url` and hung on a duct with no tty. a grove's
vault is `os.direct` (plaintext, no unlock) — correct, because the value is a
profile name and not a secret.

## .why the skill proves with sts and never with a file read

every one of the three failures above produces a **file that reads perfectly**.
so `aws.reach.set` ends its apply with a live `sts get-caller-identity --profile
<name>` and compares `.Account` against the account it was asked for. a ✔ is
earned by that call, never by the write (`rule.require.upgrade-entries-verify-themselves`).

the account comparison catches the one input that fails *silently*: an account
id valid in shape but wrong in fact yields a profile that assumes cleanly into
somewhere else, and every later error is about the wrong resource.

## .why it is a SKILL and not a bundle phase

a bundle converges the machine toward one declaration. this is per **org+env**,
and which orgs a box needs is a property of the work on that box, not of the
box's baseline. grove-1 needs `ahbode`; a grove that only builds ehmpathy
packages needs none.

`5.6.aws` accordingly owns exactly what EVERY box needs — its own identity — and
this skill adds the reaches that box's work requires. if a grove's org set ever
becomes declared state, this becomes a bundle that loops the skill over that
declaration.

## .why per org+env, not per repo

a keyrack slug is natively `<org>.<env>.<KEY>`, so org+env is already the axis
the rack indexes on. ten ahbode repos that all test against `<prep-acct>` share
one entry. what genuinely varies per repo is the **account number** — and that
is why `--account` is read from `declapract.use.yml` rather than typed.

## .the evidence

- `.agent/repo=.this/role=any/skills/aws.reach.set.sh` — the skill, with the
  full reason for each choice in its header
- `src/grove.provision/5.devtools/5.6.aws/` — `ambient`, `[default]`, and the
  empty credentials file, each with its own measurement
- `src/zshenv.sh` — why the pointer is in `.zshenv` and not `.zshrc`

## .see also

- `howto.give-a-box-an-aws-account.md` — the human's path
- `rule.require.identical-commands-on-every-server` — the rule this serves
- `rule.forbid.two-writers-on-one-artifact` — and why the fences satisfy it
- `domain.terms/term=ambient` — the box's own identity vs a rack entry
- `domain.terms/term=wrapper` — why the grove gets no `AWS_PROFILE=… cmd` prefix
