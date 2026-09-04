# domain.term.choice.reason: env

## .etymology

`env` is how unix writes `environment`, and has been since `env(1)` shipped. the platform this repo
provisions uses the short form everywhere a machine reads it — `environ(7)`, `printenv`, `$ENV`,
`.env`, `NODE_ENV` — and the long form only in prose.

so the alias is not an economy this repo invented. it adopted the one its own domain already speaks
(`rule.require.ubiqlang`: take the word the domain uses, do not translate it).

## .the blessed-alias doctrine

`rule.forbid.domain-term-synonyms` exists because two words for one concept split a vocabulary.
`env`/`environment` is two words for one concept — so it needs an explicit verdict, or every reader
re-litigates it.

the verdict: **`env` is a blessed alias.** it is the canonical form; `environment` is its forbidden
long form.

a **blessed alias** is a short form that satisfies all four:

1. **it is already how the domain writes it**, not a form this repo coined
2. **it is unambiguous in scope** — no other concept here shortens to `env`
3. **it appears in a repeated position**, so the length is paid over and over
4. **exactly one form is canonical** — the alias does not coexist with its long form; it REPLACES it

the fourth is what makes a blessed alias different from mere tolerance. both spellings allowed would
be the drift the rule forbids. `env` allowed and `environment` forbidden is one word per concept,
which is the rule satisfied.

### why a short form is normally a smell

`rule.forbid.ambiguous-labels` warns against "cryptic abbreviations", and it is right to. most short
forms fail test 1 — they are private economies (`cfg`, `mgr`, `svr`, `usr`) that a reader must
decode. the decode cost is paid by every reader, forever, to save the author a few keystrokes once.

`env` fails none of the four. a unix engineer does not decode `env`; they read it.

## .disputes

### dispute: `environment` — raised 2026-07-30 — status: RESOLVED (keep `env`)

- raised.by  = mechanic, who had deferred the question one round earlier rather than settle it
- claim      = the concept is sdk-environment's `Environment`, and `rule.require.conform-to-sdk-
               environment` demands conformance "by name and value". the package's dobj is written
               `Environment`. so the conformant form is the long one, and `env` is this repo's
               private shortening of a published contract — precisely the drift that rule exists to
               stop
- counter    = conformance is to the **concept and its values**, not to a typescript identifier's
               case and length. the same rule already accepts a transformation the claim would
               forbid: the package's `Environment.access` becomes `GROVE_ENV_ACCESS` here, because
               the contract is typescript and this repo is bash. the shapes cross as strings; the
               identifiers cannot cross unchanged at all.

               and the long form is worse ON the very platform under conformance. bash has no
               namespace, so every exported name carries its full prefix, and `env` is what unix
               itself calls this. `GROVE_ENVIRONMENT_ACCESS` conforms to a spelling while it
               violates the idiom of the language it is written in.

               the human settled it directly: **"env = environment. its a blessed alias."**
- resolution = keep `env` as canonical; record `environment` as its forbidden long form. the
               CONCEPT stays imported and is not claimed as ours — `access`, `server`, `commit` are
               sdk-environment's and are not itemized here. only the alias is this repo's, and only
               the alias is itemized. dispute closed.

## .evidence

### the boundary that actually matters

the real hazard with `env` is not its length — it is **scope creep downward**. `env` names the whole
dobj, and the temptation is to say "env" and mean one attribute:

```sh
--env prep          # 👎 this is `access`, not the env
ENV=prod            # 👎 same
GROVE_ENV_ACCESS   # 👍 the attribute is named
```

that collapse is already forbidden by `rule.require.conform-to-sdk-environment`, which lists `env`
alone-for-access among its forbidden synonyms. the two verdicts stand together and are not in
tension:

- **`env` for the dobj** → blessed
- **`env` for `access`** → forbidden

which is the same shape as every good alias verdict: the short form is canonical AT ITS OWN LEVEL,
and may not drift down a level to name one of its parts.

### where the alias is load-bear

the three exports are read on every header line of every bundle run:

```sh
GROVE_ENV_ACCESS="prep"            # test | prep | prod
GROVE_ENV_SERVER="cloud@aws.ec2"   # $tier@$platform
GROVE_ENV_COMMIT="main@a1b2c3d+"   # $gitref@$hash, + when dirty
```

and in the probe names the round of 2026-07-30 declared:

```sh
grove_env_probe_aws_ec2    grove_env_probe_desktop    grove_env_server_tier
```

the long form would add eight characters to each of six exported names, in a prefix that never
varies. that is the "repeated position" test, met concretely.

## .invariants

- exactly ONE form is canonical, and it is `env`. `environment` in a contract = a synonym violation,
  not a stylistic preference
- `environment` may appear in PROSE that quotes sdk-environment's dobj by name (as this file does),
  because that is a citation of another repo's identifier, not a name of ours
- `env` never names one attribute. `access`, `server`, and `commit` have their own words, and the
  downward drift is the one failure this alias can cause
- the alias is ours; the concept is not. if sdk-environment renames the dobj, the CONCEPT moves and
  this alias follows — it does not anchor the concept in place
