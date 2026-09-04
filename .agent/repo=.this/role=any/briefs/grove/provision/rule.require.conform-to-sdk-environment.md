# rule.require.conform-to-sdk-environment

## .what

this repo's notion of "which machine is this?" must conform to the **`ehmpathy/sdk-environment`**
contract — its terms, its shapes, and its values. an `Environment` is a domain object of three
attributes, and it is what travels down the bundle tree:

```ts
interface Environment {
  access: 'test' | 'prep' | 'prod';   // what resources may we touch?
  server: string;                     // where does this run?  `$tier@$platform`
  commit: string;                     // what code is this?    `$gitref@$hash` (+ if dirty)
}
```

the repo's extant `--for local|cloud` axis is **not a new idea**. it is `server`'s tier:

```
server.split('@')[0]  →  'local' | 'cloud'
```

so `--for` conforms by derivation into `server`, and a grove is literally `cloud@aws.ec2`.

## .why conform rather than keep a private tag

the human: *"and its not a tag; its an env dobj … try and conform to sdk-environment terms and
shapes for the env, and formalize adherance to that contract too"*.

### 1. it is the same concept, already modelled, already published

`sdk-environment` exists to answer exactly the question `--for` was invented to answer, and it
answers it with more precision. a private two-valued string beside a published three-attribute dobj
is a **second vocabulary for one concept** — which `rule.require.ubiqlang` forbids and which this
repo has paid for three times (`install_env.grove.sh`, the rsync/tar carriers, the terminfo lesson
trapped inside a `local` step).

### 2. it un-mashes two questions the tag had welded together

this is the concrete win, not merely tidiness. `--for local` is really **two** questions in one
word, and `rule.require.every-function-has-a-driver` gives the game away in its own test:

> could a headless cloud box use this, **and** can it install with no human present?

two questions, one answer. so a step that needs a *screen* and a step that needs a *human's
identity* got the same tag, and no reader can tell which reason applied.

`server` splits them for free, because `$platform` is a first-class half:

| `server` | screen? | human? | the case |
|---|---|---|---|
| `local@unix` | yes | yes | the laptop |
| `cloud@aws.ec2` | no | no | a grove |
| `local@cicd` | **no** | **no** | a ci runner — `local` tier, and no human present |

**`local@cicd` is the case a two-valued tag gets wrong**, and it is the clearest illustration of
why `$tier@$platform` beats `--for local|cloud`: it is `local` tier, so a `--for local` run would
try to install a GPU terminal emulator, a firefox flatpak, and a keyd remap on a ci runner. one
word cannot hold both halves; two can.

> ⚠️ `local@cicd` is an **illustration, not a detected platform**. the repo detects exactly two
> (see the closed set below), and `cicd` has no probe because no ci runner runs a provision. the
> vocabulary is what conformance buys — the *shape* is right whether or not a third box ever
> arrives. do not read this row as a claim that the code detects it.

### 3. `access` is an axis the repo lacks and needs

`access: test | prep | prod` is **orthogonal** to `server` — the package is explicit that a laptop
may hold `prod` access and a lambda may hold `test`. this repo has no word for that today, which is
why `clone_org_repos` and `install_gh_cli` cannot express "clone the prep set, not the prod set".
conformance supplies the axis before it is needed rather than after.

## .the vocabulary — adopt these words, and only these

| term | values | what it answers |
|---|---|---|
| `access` | `test` \| `prep` \| `prod` | what resources may we touch? |
| `server` | `$tier@$platform` | where does this run? |
| `commit` | `$gitref@$hash`, `+` when dirty | what code is this? |

### forbidden synonyms

| forbidden | use | why |
|---|---|---|
| `dev` | `prep` | names WHO uses it, not WHAT happens there (`prefer.env_access.prep_over_dev`) |
| `env` alone, for access | `access` | `environment` is the whole dobj; `access` is one attribute |
| `--for local\|cloud` as the stored form | `server` | it is `server`'s tier, so keep one shape |
| `host`, `platform`, `machine kind` | `server` | three words for one attribute |
| `sha`, `version`, `build` | `commit` | the contract names it `commit` |

> the pre-production tier has one word, and it is `prep`. every other candidate — including the one
> this repo's own hooks refuse to let a file spell — is out.

`--for local|cloud` survives as a **cli convenience**: a human types it, and it derives at once into
`server`. what it may never be is the shape a bundle reads.

## .the bash form

the contract is typescript; this repo is bash. so conformance is by **name and value**, and the
shapes are strings, which cross the boundary intact:

```sh
GROVE_ENV_ACCESS="prep"            # test | prep | prod
GROVE_ENV_SERVER="cloud@aws.ec2"   # $tier@$platform
GROVE_ENV_COMMIT="main@a1b2c3d+"   # $gitref@$hash, + when dirty
GROVE_MODE="plan"                  # plan | apply — travels alongside, not part of Environment
```

and the one derivation the contract blesses, wrapped once so it is never hand-rolled twice:

```sh
# .what = the tier half of $server — the axis `--for` used to name
# .why  = the contract states `server.split('@')[0]` is always parseable. wrapped
#         so a reader never has to know that, and so a second copy cannot drift
grove_env_server_tier() { echo "${GROVE_ENV_SERVER%%@*}"; }
```

### why exported variables and not arguments

a bundle tree is arbitrarily deep, and every node would otherwise thread the same three values
through every call. that is the shape `rule.require.input-context-pattern` calls **context**:
injected, ambient to the callee, never a positional arg. exported variables are bash's context.

`GROVE_MODE` sits beside the environment rather than inside it, because `mode` is a property of
**this run**, not of the machine. the contract has three attributes and gains no fourth.

## .the parser chain — derive once, at the entrypoint

the package's design is an ordered list of parsers, first non-null wins, with an envar override
ahead of every inference. conform to that order:

```
access:  GROVE_ENV_ACCESS override  →  (default: prep)
server:  GROVE_ENV_SERVER override  →  --for flag (tier only)  →  ec2 detect (free)
                                    →  desktop detect  →  ec2 detect (imds)  →  ✋ refuse
commit:  GROVE_ENV_COMMIT override  →  git describe + rev-parse + dirty check
```

derived **once**, in `grove.provision._.sh`, then propagated. a bundle that re-derives any attribute
has made a second parser, and two parsers of one fact drift — the defect this repo already fixed
once, when `install_env._.sh` held its own copy of the `--for` detection until 2026-07-27.

## .one file, and named probes inside it

`server` is the attribute the repo actually has to *detect*, and detection is where a second
vocabulary would most easily grow back — every caller that wants to know "am I on a grove?" is a
caller tempted to read a file itself.

so the whole of it lives in **`src/grove.env.sh`**, and inside that file each candidate platform
is a **named probe function**:

```sh
grove_env_probe_aws_ec2         # four FREE rungs — dmi, systemd, cloud-init, xen uuid
grove_env_probe_desktop         # a graphical session, by VALUE not by presence
grove_env_probe_aws_ec2_imds    # aws's authoritative answer; the only one that costs
```

the derivation is then a bare ladder of those calls, and states only the **order**.

### .the platform set is CLOSED, and has two members

`aws.ec2` (a grove) and `unix` (a laptop). that is the whole set.

it can be closed because **we own every machine this runs on** — the set is a list of boxes we
can name, not a guess about the world.

🛑 **do not add a member with no box to run it on.** probes for `aws.lambda` and `cicd` were
both correct and both unrunnable here: their only evidence was that aws publishes such
envvars, never that a box *here* sets them (`rule.prefer.wet-over-dry`). **an unrun probe is
an unproven probe.**

### .and there is NO fallback — an undetected box is an error

a fallback exists to cover boxes you cannot enumerate. there are none. so the derivation
**returns 2 and names the fix** — the two one-word overrides — rather than pick the likelier of
two (`rule.require.errors-name-the-fix`).

🛑 **never close the derivation with `platform="${platform:-unix}"; tier="${tier:-local}"`.**
a box that answers no probe is then **silently called a laptop** and the derivation reports
success — `rule.forbid.failhide` exactly. and `local@unix` is the value every interactive gate
reads as *"a human is at a keyboard"*, so the default for "I could not tell" is the more
dangerous answer.

📜 measured 2026-07-30: a real grove took that line and was offered an `ssh-keygen` passphrase
prompt on a duct.

> we control our environments. so the job is not to guess well — it is to detect reliably, and to
> say so when we cannot.

### .why named probes and not an inline `elif` wall

a probe you can call is a probe you can *test in isolation*, and that is not a stylistic
preference — it is what finds the defects. two were found on 2026-07-30, and **both were invisible
to an end-to-end check of `$server`**: one probe that wrongly declined, and one that wrongly fired
while hidden behind a correct one.

> a chain that can only be asked for its verdict cannot tell a correct answer from two errors that
> cancel.

### .the detail lives in ONE place, and it is not here

the cascade order, the per-rung evidence, the nine candidates measured and the five rejected, the
aws citations, and the test matrix are all in **`howto.detect-env-server`**.

they are deliberately not repeated here. this rule owns the **vocabulary** — that `server` exists,
what shape it takes, that it is derived once. the howto owns the **detection** — how that one value
is actually measured, and how a traveler proves it after a change.

two homes for one fact drift, which is the same argument this rule makes about `--for` and
`server`. so: change detection there, and change the words here.

## .the adherence this rule formalizes

1. **the words** — `access`, `server`, `commit`. no synonym, in any contract or in any comment that
   names the concept
2. **the values** — `test|prep|prod`; `$tier@$platform`; `$gitref@$hash[+]`. no private enum
3. **the split** — tier is read via the wrapped derivation, never by an inline `%%@*` at a call site
4. **one derivation** — parsed once at the entrypoint, propagated after; never re-derived
5. **orthogonality** — `access` and `server` are independent. code that infers one from the other
   has collapsed two axes the contract keeps apart

## .the caveat

`sdk-environment` is a **node package**, and this repo's provisioner is bash that runs *before*
node exists on a fresh machine. the repo cannot IMPORT it, so conformance is to its contract, not
its code.

no compiler can hold us to it, so review and the term glossary must. an unenforced contract that
nobody re-reads is how a private vocabulary grows back.

> conform by vocabulary where you cannot conform by import — and write the vocabulary down, because
> no other force will hold you to it.

## .enforcement

- a private machine-kind enum beside `server` = **blocker**
- `dev` used where the contract says `prep` = **blocker**
- `--for local|cloud` stored or read as a bundle's applicability input = **blocker** (it is a cli
  form; derive it into `server`)
- an attribute re-derived below the entrypoint = **blocker** (two parsers of one fact)
- a platform test written inline at a call site, rather than as a named probe in `grove.env.sh`
  = **blocker** (it cannot be asked on its own, so it cannot be proven)
- a probe adopted on the strength of one box = **blocker** (a signal measured on one machine is a
  true statement, not a discriminator)
- a probe whose name claims more than its test checks = **blocker** (`desktop` that passes on a
  `tty` session; `has_screen` that reads a string)
- a probe for a platform no machine here runs = **blocker** (an unrun probe is an unproven one)
- a DEFAULT platform or tier where detection failed = **blocker** (`rule.forbid.failhide`; refuse
  and name the fix instead)
- an inline `${...%%@*}` tier split at a call site = **nitpick** (use the wrapped derivation)
- `access` inferred from `server`, or vice versa = **blocker** (they are independent axes)

## .see also

- `ehmpathy/sdk-environment` — the contract. read `readme.md` before any change here
  (`rule.require.read-package-docs-before-use`)
- `rule.require.grove-provision-bundles` — the tree the `Environment` travels down; composites
  propagate it, leaves read it
- `prefer.env_access.prep_over_dev` (architect) — the `prep` argument, from the same vocabulary
- `rule.require.ubiqlang` (mechanic) — one canonical representation per concept, which is the whole
  reason to conform
- `rule.require.input-context-pattern` (mechanic) — why env + mode are context, not arguments
- `howto.detect-env-server` — **the cascade, its evidence, and its test matrix.** read it before any
  change to a probe; this rule deliberately does not repeat it
- `src/grove.env.sh` — THE declaration: the named probes, the parser chain, and the predicates a
  leaf asks
- `src/grove.for.sh` — `--for local|cloud`, DERIVED from `$server`'s tier. it holds the deprecated
  `any|local|cloud` tag vocabulary that uncomposed function steps still speak, and it shrinks as
  bundles absorb them
