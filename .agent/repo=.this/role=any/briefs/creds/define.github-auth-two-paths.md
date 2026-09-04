# define.github-auth-two-paths

## .what

github accepts two credentials, they are reached by two different protocols, and **a repo
uses exactly one of them**. which one is decided by the remote URL, nowhere else.

| | ssh | https |
|---|---|---|
| remote | `git@github.com:org/repo.git` | `https://github.com/org/repo.git` |
| credential | a public key registered to a **user** | a token, as an http password |
| how git obtains it | `ssh-agent` / `~/.ssh/id_*` | **`credential.helper`** |
| serves `clone`/`pull`/`push` | ✅ | ✅ — needs scope `repo` |
| serves `gh repo list` (the REST/GraphQL api) | ❌ | ⚠️ — needs scope `read:org` |
| identity | a human, or a machine user | a github **app** installation |
| lifetime | permanent until revoked | ~1h, re-minted |

⚠️ **those two ✅s are not one capability, and a token can hold one without the
other.** measured on grove-1, 2026-08-05, with a real classic pat on the rack:

```
git clone https://github.com/ehmpathy/rhachet-briefs-ehmpathy.git   ✔ cloned (private)
git clone https://github.com/ahbode/keyrack-infra.git               ✔ cloned (private)
gh repo list ehmpathy                                               ✋ refused
gh repo list ahbode                                                 ✋ refused
   error validating token: missing required scope 'read:org'
```

one pat, one protocol, two outcomes. **CLONE needs `repo`; DISCOVERY needs
`read:org`**, and a pat minted with only the first does every clone you name and
cannot tell you what there is to name.

that is "clone `ehmpathy/rhachet`" (works) against "clone `ehmpathy/*`" (impossible) — a
task whose scope carries a `*` is blocked by a token that clones perfectly. the `❌ / ✅`
split says ssh cannot discover; it does not say https always can.

⚠️ the proof of one is NOT the proof of the other. a session that clones a private repo
and reports "the credential works" has proven `repo` and said none of `read:org`.
a `prove.clone-both-orgs` probe asks the two separately for this reason.

## .why this brief exists

the two paths get conflated, and the conflation costs whole conversations. three claims
are each true and each surprising:

1. **an app installation token cannot authenticate ssh.** github's ssh endpoint knows only
   public keys registered to user accounts. `ghs_…` is an http bearer credential. so *"use
   app tokens exclusively"* and *"clone over ssh"* cannot both hold.
2. **`credential.helper` is never called for an ssh remote.** it is the https path's
   mechanism, entirely. on a box that clones over ssh it is dead code.
3. **ssh cannot list repos.** `gh repo list <org>` is an api call. a box with a perfect ssh
   key still cannot discover what to clone — which is exactly the failure `5.10.repos`
   reports on a grove.

so the two paths are not interchangeable, and *"just use the ssh key"* does not remove the
need for a token. it adds a second credential beside it.

## .credential.helper, precisely

a program git runs when an **https** remote answers `401`. git writes key=value pairs to its
stdin; the helper writes a username and password to stdout:

```
protocol=https             ← git asks, on stdin
host=github.com

username=x-access-token    ← the helper answers, on stdout
password=ghs_…
```

`helper = keyrack` means *run `git-credential-keyrack`* — git prepends `git-credential-`, so
the config value is a suffix, not a path.

`x-access-token` is the literal username github requires beside an installation token. the
password is the token.

⚠️ **git calls the helper three ways: `get`, `store`, `erase`.** a helper that answers all
three identically will cache a minted token to disk on `store`. both write verbs must be
explicit no-ops, so *"no secret at rest"* is structural rather than incidental.

## .the per-org route, and its one solution

by default git hands the helper only:

```
protocol=https
host=github.com
```

**no org.** so a helper cannot tell `ahbode/x` from `ehmpathy/y`, and every github repo
collapses onto one credential. that is the whole difficulty of a multi-org box.

the fix is one config key:

```
[credential "https://github.com"]
    helper = keyrack
    useHttpPath = true
```

now the request carries the path, and the org is its first segment:

```
path=ahbode/private-repo.git      →   ${path%%/*}  →  ahbode
```

**`useHttpPath` IS the per-org route.** without it the helper is blind; with it, git names
the org on every single request and the helper has all it needs.

## .private repos change no mechanism

a private repo is not a different auth path. git receives a `401`, calls the helper, retries
with what it gets back. identical to a public repo that needs a push.

what private DOES change sits outside the code: **the app must be installed on each org,
with access to those repos.** a github app installation is scoped either *all repositories*
or *selected repositories* — and a token minted for an org where the app sees a subset will
`404` on the rest, which is indistinguishable from *"that repo does not exist"*.

per org: **settings → github apps → seaturtle → repository access**, plus `contents: read`
(clone/pull), `metadata: read` (discovery), and `contents: write` only where a push is owed.

## .how keyrack mints, and why a per-org helper is blocked

keyrack mints via `EPHEMERAL_VIA_GITHUB_APP` — an `appId` + `privateKey` + `installationId`,
cached 55 minutes in the per-owner daemon's memory, never on disk. the installation id is
resolved once at `keyrack set` time and stored, so org→installation translation is already
per-key-entry.

`--org` accepts a literal org name only when it equals the checkout's own manifest org — it is
**`@this` spelled out**, not a free selector, and no `--scope` flag exists yet. that is fatal to
a *per-org* helper: git invokes the helper from whatever repo it is on, never the repo the
helper lives in.

the helper this repo built sidesteps the gap: it asks for one slug that belongs to no org,
`@all.camp.GITHUB_TOKEN` (`rule.require.github-token-at-all-camp`) — untested past that point,
since no readable token has existed yet.

**the long-term fix is `--scope github://org/<org>`**, not a literal-org selector: one key
entry, scoped per grant, rather than one entry per org — a **feature request against rhachet**,
not an extant flag.

.refs = gotcha.github-auth-two-paths.demo=keyrack-mint-and-org-gap, m1-m2

## .the split by machine — settled, and finer than "ssh local, https cloud"

| piece | tag | why |
|---|---|---|
| the helper file on PATH | **`any`** | a laptop with keyrack unlocked wants it too. the machine-specific part is the REWRITE, not the helper |
| `credential.helper` + `useHttpPath` | **`any`** | inert on a box with only ssh remotes; costs no harm |
| `url.insteadOf` ssh→https | **`cloud`** | on a laptop it breaks agent-forwarding, commit signing, and second accounts |
| the human's ssh key | **`local`** | an ssh key on github authenticates **you** — a copy on a grove makes a lost grove a compromised account |

so, in practice:

- **laptop** — ssh, authorized by the yubikey behind `SSH_AUTH_SOCK`. already works.
- **grove** — https + app token. one credential covers clone, pull, push, **and** discovery.
  no secret at rest, and no credential that acts as a human.

## .the bootstrap case — no circle, on one condition

`devenv.bootstrap.sh` clones this repo **anonymously over https**, because `dev-env-setup` is
**public**. no credential, no keyrack, no node. only then does `grove.provision` install the
helper, and every private repo afterward is covered.

```
bootstrap   anonymous https, public repo    → no credential needed
upgrade     installs keyrack + the helper   → credential exists
private     helper routes by path → org     → works
```

⚠️ **that ordering holds only while this repo is public.** if `dev-env-setup` ever goes
private, bootstrap needs a credential to fetch the thing that installs the credential system
— `plan.grove-credentials.md`'s constraint-2 circle, reopened. the repo's visibility is
therefore a load-bearing constraint, not an incidental fact.

and a grove has no `git pull` of this repo at all: its `provenance` is `pushed`, so
`grove.push` rsyncs `src/` with no `.git`. `devenv.pull.repo` is a laptop verb.

## .what is NOT yet built

| piece | state |
|---|---|
| `git-credential-keyrack` on PATH | **absent** — no writer anywhere in the tree |
| `credential.helper` / `useHttpPath` config | **absent** — `2.2.git` sets identity, defaults, aliases; no credential config |
| `url.insteadOf` ssh→https | **absent** |
| `keyrack get --scope` | **absent upstream — task DISPATCHED 2026-07-31.** blocks a working helper, blocks nothing else |
| ahbode/ehmpathy/nheuron on `EPHEMERAL_VIA_GITHUB_APP` | **unmigrated** |
| the ssh path | **fully coded** — `2.3.ssh` generates a key on headless boxes; `5.10.repos/configure.upsert.sh` probes github, sets `git_protocol ssh`, repairs the origin |

that the ssh half is complete is why *"just use ssh"* is tempting. it does not close
`5.10.repos`, because `provision.upsert` fails **first** on `gh auth status`, and the phase
chain then skips the configure phase that would have done the ssh work.

## .the solution

**one credential, minted per org, held in memory, reached over https.** the grove has no
github identity of its own — it presents keyrack's, scoped down to the org git names.

### the chain, end to end

```
git needs github.com/ahbode/x        (https remote — the CLOUD rewrite guarantees it)
  └─► credential.helper = keyrack     + useHttpPath = true
        └─► git-credential-keyrack    an ASSET under src/machine/
              org = ${path%%/*}       ahbode/x.git → ahbode
              └─► rhx keyrack get --scope github://org/ahbode
                    └─► EPHEMERAL_VIA_GITHUB_APP
                          appId + privateKey + installationId → a ~1h token
                          held 55m in the per-owner DAEMON, in memory
              ◄── username=x-access-token / password=ghs_…
```

### what each piece is

- **the helper is an asset, not an inline config value.** `src/machine/git-credential-keyrack`,
  installed to `~/.local/bin`, owned by one bundle phase and `cmp`'d by its verify. the
  inline `!f() { … }; f` form is unreviewable, untestable, and undiffable
  (`term=asset._.choice._.md`).

- **the helper holds no secret and no policy.** it translates git's question into keyrack's:
  read stdin, take the org from `path`, ask, print. `store` and `erase` are explicit no-ops,
  so *"no token at rest"* is structural rather than incidental.

- **a decline is not a failhide.** on a non-github host, or an org keyrack cannot serve, the
  helper names its reason on **stderr** and exits **0** with empty stdout — git's protocol
  for *"I cannot help; try the next helper"*. a hard exit would break every https remote the
  helper was never meant to serve.

- **the org is carried by git, never inferred.** `useHttpPath = true` is what puts `path=` in
  the request. `@this` cannot serve here: the helper runs against whatever repo git is on,
  which is not the repo the helper lives in.

- **the scope is a property of the REQUEST, not of storage.** one key entry, scoped per
  grant — the jwt-scope model. the manifest stays flat as orgs multiply.

- **the token is never written down.** minted on demand, held 55 minutes in keyrack's
  per-owner daemon (in-memory, unix socket), with git's `cache --timeout=3000` chained after
  the helper so a bulk clone costs many `rhx` spawns but ~1 **mint** per org. a file cache
  anywhere in this chain would undo the one rule.

### where each piece applies

`.the split by machine` above holds the per-piece tags.

### the two things this repo cannot declare

- **`keyrack get --scope`** — upstream in rhachet; **task dispatched 2026-07-31**. the helper
  is buildable and mergeable before it lands, and declines cleanly until it does.
- **the app installation per org** — `ahbode`, `ehmpathy`, `nheuron` still hold seaturtle as
  `PERMANENT_VIA_REPLICA`. each needs the app installed with **repository access = all
  repositories**, else a minted token 404s on what the app cannot see — indistinguishable
  from an absent repo.

## .the open question worth a measurement

**does `gh repo list <org>` work under an installation token?** it is the call that fails on
grove-1 today. `git` operations certainly work under one; the *discovery* call is the
uncertain half, since github apps enumerate via `GET /installation/repositories` while
`gh repo list` goes through graphql.

if it works, https-on-grove closes `5.10.repos` outright. if not,
`5.10.repos/provision.upsert.sh:71` swaps to that endpoint — a one-line change that does not
touch the helper.

## .one operational note

with `useHttpPath = true`, git's own `cache` helper keys per **path**, so it will not reuse
one org's token across that org's repos. chain the memory cache after the helper:

```
credential.helper = cache --timeout=3000
```

keyrack's daemon absorbs the rest, per `.the token is never written down` above.

⚠️ **do not add a file cache to the helper.** it would write a live token to disk and undo
the one rule below. `cache` is memory-only by design, and keyrack's daemon is the sanctioned
place for a held token (`os.daemon`).

## .the one rule this all serves

> the grove derives its secrets by proof of identity; it is never handed a master key.

a compromised grove must yield only a short-lived derived credential — never the seaturtle
app private key, and never a credential that outlives the box.

## .see also

- `plan.grove-credentials.md` — the credential plan, its five phases, and the constraints the
  human settled 2026-07-26
- `rule.require.security-paramount` — why a token file at rest is the thing to avoid
- `src/grove.provision/5.devtools/5.10.repos/configure.upsert.sh` — the ssh path, fully coded
- `src/grove.provision/2.shell/2.2.git/configure.upsert.sh` — where the credential config belongs
- `term=provenance._.choice._.md` — why a grove has no `.git` to pull
