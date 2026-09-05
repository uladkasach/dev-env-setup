# domain.term: shim

term.chosen   = shim
term.kind     = noun
term.synonyms.forbidden:
- wrapper      (a wrapper ADDS behavior; a shim adds none — it only redirects)
- alias        (a shell mechanism; a shim is a FILE, because `rhx` reads a dir)
- proxy        (implies it stands in for something absent; a shim's target is present)
- facade       (implies it simplifies a wide surface; a shim changes no surface at all)
- stub         (a stub answers in place of the real thing; a shim never answers)
- symlink      (names the mechanism, and the wrong one — see .reason)
- forwarder    (says the direction, not the reason; and reads like a mail relay)

## .what
a file at a path callers already know, whose whole body finds the one real
implementation and `exec`s it. it holds no logic of its own — a reader who opens
it learns only WHERE the bytes live.

a shim keeps `rule.forbid.two-writers-on-one-artifact` when two paths reach one
concern: exactly one file holds the bytes, and every other path `exec`s it.

## .the test
a file is a shim when all three hold:
- it changes no behavior — same args in, same exit code out
- its body finds a target and `exec`s it, and does no other work
- deletion of the TARGET breaks it; deletion of the shim costs only the
  convenience path

a file that transforms args, adds a retry, or prints its own report is a wrapper,
not a shim.

## .the order a shim owes
a shim that names two candidates must say which wins and why. the extant one
prefers the CHECKOUT over the installed copy, so `rhx` runs what the repo
declares even mid-edit:

```
src/machine/<x>.sh        # the checkout — preferred
~/.local/bin/<x>          # the installed copy — the fallback
✋ …absent                # neither — a named error, never a silent no-op
```

## .a shim may be authored by a TOOL, and then nobody owns its order

every ref below is a shim this repo WRITES, so the section above reads as advice to
its author. but the term covers any file of this shape, and the ones that bite
hardest come from a package manager — `pnpm` lays a `rhx` shim beside every global
install, and no phase of this repo declares it.

⚠️ **a tool-authored shim can be DUPLICATED, and then PATH order decides the winner.**
measured on grove-1, 2026-08-05:

```
$PNPM_HOME/bin/rhx    1467 b   aug 3   ← stale; errors on every call
$PNPM_HOME/rhx        1291 b   aug 5   ← current; runs
PATH: …/pnpm/bin  then  …/pnpm         ← so the STALE one answered
```

pnpm treats `$PNPM_HOME` itself as the global bin dir in some versions and a `/bin`
child in others, so an upgrade can write the new shim to the dir the old one is NOT
in. both persist, both carry the name `rhx`, and an order three files in this repo
pin decides which answers (`src/zshrc.sh`, `5.1.node`'s two phases).

### ✔ WHY the two dirs — it is the CWD, not the version (2026-08-06)

the block above blames a version change over time — an inference from two dated
readings. asked directly, grove-1 answered both ways within one second
(`diagnose.pnpm-bin-dir-per-cwd`):

| cwd | `packageManager` above it | pnpm that answered | `pnpm bin -g` |
|---|---|---|---|
| the repo | `pnpm@10.24.0` | **10.24.0** | `$PNPM_HOME` |
| `$HOME` | none | **11.20.0** | `$PNPM_HOME/bin` |

corepack's `pnpm` is a **dispatcher**: it runs the version the nearest
`packageManager` names, and its global default where none sits above the cwd.
`5.1.node` had set that default with `corepack install -g pnpm@latest`, so the box
held two pnpms with ONE binary on PATH — and 10.x and 11.x disagree about the
global shim dir.

⇒ **a fossil needs two installs in two PLACES, never an upgrade over time.** the
08-02 and 08-06 readings differ by directory; a calendar cannot tell that from a
version bump.

### ✔ the fix, in two halves

- **the source** — `5.1.node` installs the pnpm the repo DECLARES
  (`packageManager`, stamped by declapract) rather than `@latest`, so both cwds
  converge on one pnpm and one dir and no new fossil can be born
- **the residue** — the same phase asks `pnpm bin -g` and prunes the shadowed copy
  from the other dir, since a pin cannot un-write a file already on disk

the PATH order in all three declarations stays, demoted to a tiebreak for boxes
that still hold duplicates.

⚠️ the first prune run cleared **three** fossils: `claude codex rhachet`. `rhachet`
is the very shim named in the block above — repaired by hand on 08-05 for one
command, and still a fossil for the rest. a per-instance fix leaves the class open
(`rule.require.clamp-edge-cases`).

### ⚠️ the `.test` above needs one amendment for this case

the third bullet says deletion of the shim costs only the convenience path. that
holds for ONE shim. with two, **deletion of the stale shim IS the repair** — it
uncovers the current one behind it. so:

> a duplicated shim is not a redundancy. it is a stale answer that outranks a
> correct one, and the fix is to delete a file rather than to install a package.

### .why this distinction earns its keep

a human reported `rhx` broken. two different defects wore that one sentence:

| what was wrong | what fixes it |
|---|---|
| the SHIM was stale — it pointed at an old install | delete the stale file |
| the TARGET was incomplete — a dep absent from the store | reinstall the package |

both present identically to a human. **delete a shim and you lose a path; delete
its target and you lose the tool.** so the first question on any "X is broken" is
which of the two you face. a session that skipped it spent several rounds on a
reinstall for a PATH problem.

## .refs
- .agent/repo=.this/role=any/skills/kitty.snapshot.terminals.sh  # the first one
- src/machine/kitty.snapshot.terminals.sh                        # its target (an asset)
- .agent/repo=.this/role=any/briefs/evidence/rule.forbid.two-writers-on-one-artifact.md
- src/grove.provision/5.devtools/5.1.node/_.sh                    # the pin + the shadow scan

## .reason
see the ref-level cluster beside this choice:
- `term=shim._.choice.reason.md` — the etymology, why it is not a symlink, the
  2026-07-31 duplication that produced it, and the FOSSIL shim a tool authors
