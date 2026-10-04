# demo: git-credential-keyrack — every measurement behind the helper's reads and its ladder

## .what

`2.2.git/git-credential-keyrack.sh` lets plain `git` over https draw `@all.camp.GITHUB_TOKEN`
from the rack. each section below is a measurement or argument that shaped one block of it.
the helper keeps the outline.

## m1 — ✔ PROVEN end to end, 2026-08-05, rhachet@1.45.1

a private clone over plain https, from BOTH orgs, on grove-1: no ssh key, no gh, no token
exported into a shell. the read itself, cold:

```
get --org @all --env camp --key GITHUB_TOKEN --unlock --allow-dangerous --value | wc -c   → 40
```

- ⚠️ the pat needs scope `repo` for this helper. `read:org` serves gh's DISCOVERY, a separate
  capability (`define.github-auth-two-paths`). one pat, one protocol, two outcomes
- `@all` is a REQUIREMENT: a box credential belongs to no single org, and git invokes a helper
  from whatever clone the human stands in — most of which carry no manifest for `@this`
- `camp` and `GITHUB_TOKEN` name the BOX's credential, never the mechanic's
  `prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN` — tied to a robot's commit-token rotation, one
  rotation would break the other's job

## m2 — the `@all` read below keyrack 1.45.1, and two lessons that outlive it

📜 2026-08-03: the read answered `absent 🫧` and `BadRequestError: slug org '@all' does not
match manifest org`. fixed at 1.45.1.

1. part of that evidence was OUR defect: the probe that answered `absent` wrote a FAKE
   classic-pat-shaped value and never confirmed it landed — the pat firewall likely refused
   the store. `absent` was a truthful answer about an entry that may never have existed
   (`rule.require.clamp-edge-cases`)
2. ⚠️ a `✔ set` is a claim about the ENTRY, and says none of the SLUG that names it. two
   sessions read it as "the credential is placed" and were wrong both times, at the cost of a
   real pat each (`term=entry._.choice._.md`)

🛑 the refusal that still holds: do NOT answer a future read failure by a switch to `@this`.
`@this` resolves only from a checkout that holds a manifest. that substitution was tried
2026-08-03 and reverted — a tool that passes by discard of the requirement has not passed.

## m3 — it DECLINES, never fails, on every unhappy path

git reads an empty answer as "this helper has none" and moves to the next helper or a prompt.
that is right whenever the rack cannot answer — an absent rhx, an unfilled slug, a host this
box does not serve. an ERROR would break `git clone` of a PUBLIC repo, which needs no
credential. so: exit 0, empty stdout, the reason on stderr — which is what makes the helper
safe to install on every box unconditionally.

- every call is BOUNDED by `timeout`: a helper that hangs hangs GIT, inside whatever command
  called it (`rule.require.bounded-probes-in-verifies`)
- store/erase exit 0: the rack is not a cache, and a non-zero exit there makes git report a
  helper failure on an otherwise good fetch
- the stdin loop stops on a blank line, git's terminator — a read to EOF can block when git
  keeps the pipe open

## m4 — 🛑 the PROTOCOL is asked, not only the host (2026-08-31)

the host test alone answered for ANY scheme — `http`, `ftp`, any future one. the token is a
github pat with `repo` + `read:org`, so an `http` request would put it on the wire in
CLEARTEXT, to a host a downgrade or a poisoned resolver chose.

git does not protect this: a `url.<base>.insteadOf`, a server redirect, or a plain `git clone
http://github.com/…` each reach a helper with `protocol=http`, and the helper is the last
component that can refuse. a credential helper is an EGRESS boundary. the decline is silent
and exit 0, like the host decline, so a human sees the ordinary "could not read Username"
rather than a leaked token.

## m5 — the pnpm dir and NODE, for a caller whose PATH carries neither

📜 2026-08-10, grove-ahbode-v20260810, `git ls-remote https://github.com/<org>/<repo>` over ssh:

```
git-credential-keyrack: rhx absent — declines
fatal: could not read Username for 'https://github.com/…'
```

`rhx` was installed, executable, one directory away. `PNPM_HOME` reached PATH from `~/.zshrc`
alone, so the helper answered a human at a keyboard and declined for ssh, cron, and every
suite — the same defect as a git that finds the helper by PATH, one layer out.

- the helper names the dir itself: it is exec'd BY GIT, from bash, zsh, a node child, or a
  cron — no rc is common to all of them
- it APPENDS: a caller who carries a pnpm dir chose one, and this must not outrank it
- a SECOND rung, node: the pnpm block put `rhx` on PATH and the next call still died with
  `/usr/bin/env: 'node': No such file or directory`. a shim FOUND that cannot run is, from
  git's side, the same empty token as one absent
- it names fnm's `aliases/default/bin`, never the `fnm env` multishell dir — that one is minted
  per shell and dies with it
- an absent rhx is no error: `2.2.git` declares the helper at position 2 and brains arrives
  at 5.3, so on a fresh box the helper exists before its reader does

## m6 — the ladder runs MOST-OWNED first, since the cwd's MANIFEST loads before the sigil

a cwd-first ladder rests on "the cwd is right for fetch/push, only clone needs a fallback".
that holds for the CWD and fails for the RACK:

```
cd ~/git/ahbode/svc-chat && rhx keyrack get … --org @all …
  → BadRequestError: extended keyrack not found
     path: .agent/repo=bhrain/role=reviewer/keyrack.yml
     from: /home/camper/git/ahbode/svc-chat/.agent/keyrack.yml
  → 0 bytes

cd ~ …the same get, from a dir the helper controls   → 40 bytes ✔
```

rhachet LOADS `.agent/keyrack.yml` from the cwd before it considers the org sigil, so a clone
whose manifest `extends` a file it does not vendor kills the read — and `2>/dev/null` turns
the throw into one empty string, the same as an absent credential. *"the cd is harmless since
`@all` needs no manifest"* is half right: `@all` needs no manifest for the ORG, and still
needs the cwd's to LOAD.

- rhachet's cli resolves the repo root before any subcommand, and `git clone` runs the helper
  with the PARENT as cwd — so the cwd is chosen, never inherited
- the `cd` is in a SUBSHELL so it does not leak into the rest of the helper

## m7 — 🛑 rung 2 tests the MANIFEST, never `.git`

`[[ -d "$p/.git" ]]` is a PROXY for "is this a checkout", and the rung needs "does this dir
hold the manifest that declares the key". the proxy is false for the population the rung
exists to serve:

| how this repo lands on a box        | `.git`        |
|-------------------------------------|---------------|
| `git clone`                         | a directory ✔ |
| `git.grove.push --from . --into …`  | ABSENT      ✋ |
| a git worktree                      | a FILE      ✋ |

the middle row is THE provision (`rule.require.one-command-provision`: push, then apply).

📜 2026-08-15, grove-ahbode-v20260811, built from scratch (`diagnose.credential-helper-ladder`):

```
· rung 2  /home/camper/git/more/dev-env-setup
  ├─ shape:                pushed copy (NO .git)
  ├─ holds the manifest:   YES   ← what the rung NEEDS
  └─ passes [[ -d .git ]]: no    ← what the rung TESTED
⇒ rung 4 (the cwd) → …/git/ahbode/svc-chat

✋ …/git/ahbode/svc-chat — 0 bytes
✔ …/git/more/dev-env-setup — 40 bytes
```

0 bytes is a DECLINE, and a decline ends in git's terminal prompt. on a duct that prompt sits
on the pane and eats every command sent afterward — how `git.grove.provision test` step 1
wedged on a converged box.

⚠️ a manifest test is SAFE on evidence: the note that "`rhx` from a non-repo dies with `Not
inside a Git repository`" was disproved for this call — the pushed copy answered 40 bytes, and
so did `$HOME`, neither a repo (`rule.require.trust-but-verify`). the rung still points at a
CHECKOUT, since the read validates the slug against the manifest.

## m8 — 🛑 rung 4, "whatever repo the human is in", DELETED 2026-08-31

- the SECURITY half: the helper `cd`s into $REPO, and rhachet LOADS that dir's manifest, which
  may `extends:` other paths. so the config a credential helper loads was picked by whichever
  directory a shell sat in when git fired — a clone of a public repo is a dir an outside party
  authored, and the helper runs on EVERY private fetch, with the rack unlocked
- the FUNCTIONAL half, which made the delete free: m7 IS rung 4 misfired. the rung already
  called "correct only by luck" was the recorded cause of a wedge, and never earned a ✔
- ⇒ no replacement rung. rung 1 (`$GIT_CREDENTIAL_KEYRACK_REPO`) names any location rungs 2-3
  do not — a DECLARATION made once, rather than a guess made per call. a refusal with a
  copy-paste fix beats a read from a source neither party chose

### 🛑 there is NO `credential.keyrackRepo` git config, and there must not be

📜 2026-08-31: a comment and the refusal's fix-text both named one, and the fix-text LED with
it — a human who followed the helper's only instruction would set a key no line reads, re-run,
and get the same refusal (`rule.require.errors-name-the-fix`).

and it is no key to add: `git config --get` reads the config of the repo the caller STANDS
IN, the exact source m8 refuses, and a `--global` read would be a SECOND holder of one fact,
free to disagree with the env var (`rule.forbid.two-writers-on-one-artifact`).

## m9 — the get's flags, and why the empty-token message names no cause

- `--unlock`: a key at rest is LOCKED; without it the get returns empty and exit 0 forever
- `--allow-dangerous`: keyrack refuses a long-lived token through a replica vault (`detected
  github classic pat (ghp_*)`). the refusal is CORRECT; the flag is phase 1's debt, and phase
  2's app token retires it (`grove.auth.github.roadmap.md`)
- `2>/dev/null`: keyrack's chatter is not the helper's answer, and git reads stdout strictly
- ⇒ so the empty-token path holds one empty string that at least four faults produce —
  locked, errored, absent, refused (measured 2026-08-06). the message lists all four with
  their fixes and sends a human to `diagnose.grove-github-credential`, which can tell them
  apart
- `x-access-token` as the username: github accepts any non-empty name with a token, and this
  is the one its docs use, so a log reader sees what the credential is

## .see also

- `2.2.git/git-credential-keyrack.sh` — the helper these measurements back
- `gotcha.2-2-git.demo=credential-helper-by-absolute-path.md` — how git finds the helper
- `rule.require.github-token-at-all-camp` · `define.github-auth-two-paths`
- `grove.auth.github.roadmap.md` — phase 1 vs 2
