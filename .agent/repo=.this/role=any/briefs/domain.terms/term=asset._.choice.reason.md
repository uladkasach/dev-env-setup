# domain.term.choice.reason: asset

## .etymology

an **asset** is a possession a party HOLDS. the word carries ownership and inventory — exactly
the two properties that set these files apart from every other file in the repo: each one has a
single bundle that owns it, and each one appears in that bundle's diff.

it is borrowed from the web-build sense (`assets/` = the files a build copies verbatim to the
served tree) rather than the ledger one, because the mechanism is the same: **copied, not
transformed.**

## .why not `template`

a template is a file with holes, and the reader of the word expects a substitution pass. these
files have none — `firefox.cfg` reaches the box byte for byte, which is precisely what lets
`configure.verify` run `cmp -s` on it. to call it a template would invite the next author to add
a `sed` and quietly destroy the currency check.

## .why `payload` is BOUNDED and not forbidden

`payload` is right where the file is delivered to a mechanism that EXECUTES it rather than reads
it — the systemd guard and its units:

```
src/machine/kitty_snap_lowbatt          # a payload systemd runs
src/firefox/firefox.cfg                 # a payload firefox's autoconfig parser runs
```

the `shell.syntax.verify` skill uses the word this way, and correctly: *"src/machine — payloads
installed into ~/.local/bin"*. every payload is an asset; not every asset is a payload
(`src/tmux.conf` is read, never run).

so the pair is a genus/species, not a synonym. use `asset` for the ownership + diff claim, and
`payload` only when the point is that a mechanism executes it.

## .the evidence — two grove failures, one day, same cause

both were found by a real `--play prove.bundles.plan-apply-apply` run on grove-1 on 2026-07-31.
neither was findable on the laptop, because on the laptop the files happened to be there.

### 1. firefox — the file lived outside `src/`

`1.3.1.firefox`'s configure phase called `.agent/…/skills/firefox.systemconfig.sh install`, and
that skill wrote the two files from its own heredocs. the grove said:

```
✋ firefox.systemconfig.sh is absent or unreadable
   looked at: …/dev-env-setup.wip/.agent/…/firefox.systemconfig.sh
```

`git.grove.push --from src` carries no adjacent dir, so the box got the bundle and never the
file the bundle ran. the fix was to make the two files assets under `src/firefox/`.

### 2. kitty — the CALLER shipped and the CALLEE did not

`kitty_snap_lowbatt` — itself an asset, correctly under `src/machine/` — named a skill by an
absolute path into a git clone:

```sh
SKILL="$HOME/git/more/dev-env-setup/.agent/…/kitty.snapshot.terminals.sh"
```

so a box provisioned the documented way got the systemd timer, the service, and the guard, and
never the file all three exist to run. worse than the first case: the guard discards its own
errors and `touch`es its marker either way, so it would log *"snapped kitty session"* and write
no snap.

### the shared lesson the term encodes

> a bundle may only depend on what `src/` carries.

that is `rule.require.bundles-own-their-dependencies`, and `asset` is the noun that makes it
sayable in one word. it also buys a capability a heredoc never could:

| the bytes live... | a verify can prove |
|---|---|
| in a heredoc inside the phase | the file EXISTS |
| in an asset under `src/` | the file exists AND MATCHES this checkout |

the second is what catches a stale copy from an older revision — which passes a `grep` and
silently runs last month's config.

## .disputes

no dispute is open.

## .see also
- `rule.require.bundles-own-their-dependencies` — the rule this noun serves
- `rule.forbid.two-writers-on-one-artifact` — why exactly ONE phase may copy an asset
- `term=declared._.choice._.md` — the adjective these files carry (`a declared asset`)
- `term=bundle._.choice._.md` — the owner
- `term=probe._.choice._.md` — the `cmp` an asset makes possible is a bounded probe
