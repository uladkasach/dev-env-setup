# domain.term.choice.reason: shim

## .etymology

a **shim** in the physical sense is a thin piece slipped into a gap so two parts
that do not quite meet can bear on each other. it adds no strength and changes no
shape — it only closes a gap. that is exactly the claim this file makes: the
`rhx` skill dir and `src/` are two parts that do not meet, and a shim closes the
gap without a second copy of the bytes.

the software sense is already established (a shim layer, a shim binary) and
carries the same guarantee: **pass-through, not transform**. that guarantee is
why the word beats every alternative below.

## .why not `wrapper`

state this one plainly: the wild treats the two words as interchangeable, and
they are not the same claim:

| | a wrapper | a shim |
|---|---|---|
| behavior | ADDS some — a retry, a log trail, a cache | adds none |
| the caller sees | a different result, on purpose | the identical result |
| a read of it teaches | what it added | only where the bytes live |

`rule.require.hook-wrapper-pattern` already owns `wrapper` in this org's
vocabulary, for the additive sense (`withLogTrail(_fn)`). reuse for a
pass-through overloads one word onto two opposite claims — "this changed your
call" and "this left your call alone."

## .why not `symlink` — the sharpest rejection

a symlink serves the first half of the problem and fails the second. it earns a
record, because it is the obvious first reach:

1. **a symlink names exactly ONE target.** the shim must prefer the checkout and
   fall back to the installed copy — two candidates, in a stated order. a symlink
   cannot express a fallback; it either resolves or dangles.
2. **a dangling symlink is a silent 127.** the shim's absent branch prints a named
   `✋` that says which two paths it looked at, which is the difference between a
   reader who knows what to fix and a reader who greps.
3. `symlink` names a MECHANISM, not the role the file plays. the mechanism is
   free to change — the role is not.

so the word is not "symlink", even though a hurried reader suggests one first.
this record answers that suggestion once.

## .the evidence — the duplication that produced the word, 2026-07-31

`kitty.snapshot.terminals.sh` lived as a `.agent/` skill and only that. two facts
collided:

- `git.grove.push --from src` carries **no adjacent dir**, so a grove that got
  the `4.3.4.snapshot` bundle got a timer, a service, and a guard — and never the
  file all three exist to run (`term=asset._.choice.reason.md`)
- a human still types `rhx kitty.snapshot.terminals`, and that caller reads the
  `.agent/` skill dir

so the bytes had to live under `src/`, and a file had to stay at the `.agent/`
path. the naive fix copies to both paths — which is
`rule.forbid.two-writers-on-one-artifact` word for word. its failure mode is the
worst kind: two files that agree today, diverge in a month, and answer one command
two ways with no error anywhere.

the shim makes ONE writer survive TWO callers. that is a distinct concept from
every word above, and it earned its own entry the moment it reached a filename.

## .the order, and why the checkout wins

the shim prefers `src/machine/…` over `~/.local/bin/…`. that is a judgment, so it
goes on the record:

> a skill invoked from a checkout should run what that checkout DECLARES.

the alternative — prefer the installed copy — hands an author who edits
`src/machine/kitty.snapshot.terminals.sh` and then runs `rhx` last week's bytes,
with no signal that the edit went nowhere. same class of defect as a verify that
proves PRESENCE and not CURRENCY.

the installed copy stays the fallback, because a shim must still work on a box
whose checkout moved or vanished, and the human's alias (`kitty.snap`, owned by
`2.7.aliases`) already names that installed path.

## .the FOSSIL shim — a duplicate whose second writer is a past self

a shim a TOOL writes carries a failure the hand-written one above does not: the
tool can move where it writes and leave the old file in place. the abandoned copy
is a **fossil** — pnpm's own bytes, in pnpm's own dir, that pnpm will never
refresh again.

### ⚠️ the cause is the CWD, not the calendar — a correction

this section first said pnpm "moved its shim dir between versions", inferred from
two measurements four days apart that read opposite ways. that inference was
wrong. the direct question settled it in one second — both answers taken on
grove-1 on 2026-08-06, back to back (`diagnose.pnpm-bin-dir-per-cwd`):

| cwd | `packageManager` above it | pnpm that answered | `pnpm bin -g` |
|---|---|---|---|
| the repo | `pnpm@10.24.0` | **10.24.0** | `$PNPM_HOME` |
| `$HOME` | none | **11.20.0** | `$PNPM_HOME/bin` |

corepack's `pnpm` is not a pnpm — it is a **dispatcher**. it runs the version the
nearest `packageManager` names, and its own global default wherever no
package.json sits above the cwd. `5.1.node` set that global default with
`corepack install -g pnpm@latest`, so the box held two pnpms at once behind ONE
binary on PATH, and 10.x and 11.x disagree about the global shim dir.

so a fossil needs no upgrade and no elapsed time. it needs **two installs in two
places** — one inside a repo, one from `~` — on the same afternoon. the 08-02 and
08-06 readings differ because they came from different directories, and a calendar
cannot tell that from a version bump.

> ⚠️ two readings that differ are a CORRELATION. this one rose to a cause and
> landed in five files before anyone asked the direct question —
> `rule.require.trust-but-verify` in its most ordinary costume: the inference was
> plausible, fit every fact, and was still wrong.

and it condemns the obvious fix twice over:

> a hardcoded PATH order does not merely age badly — it answers a question with no
> single answer. no one dir is right, only the dir the caller's pnpm uses.

### what it costs, and why a version check cannot see it

`5.3.brains` pinned claude at `2.1.87`. the install was correct, `pnpm list -g`
agreed, `DISABLE_AUTOUPDATER` held, and two `--mode apply` runs reported ✔ — on a
box where `claude --version` said `2.1.220`:

```
$PNPM_HOME/bin/claude  2.1.220  written 07-31   ← PATH picked this
$PNPM_HOME/claude      2.1.87   written 08-06   ← the pin
```

every apply was a no-op **because the declared state was already true**. the
inventory was RIGHT and the box ran the wrong binary, so no re-apply could close
it. a fossil is not a stale install; it is a stale ANSWER that outranks a correct
one.

### the fix, in two halves — the source, then the residue

**the source.** `5.1.node` installs the pnpm the repo DECLARES
(`"packageManager": "pnpm@10.24.0"`, stamped by declapract) rather than
`pnpm@latest`. with corepack's global default equal to the declared version, both
cwds dispatch to one pnpm and one global bin dir, so no fossil can be born. the
phase READS the pin from `package.json` rather than restate it, so it cannot
drift from declapract's (`rule.require.identical-bundle-composition`).

**the residue.** a pin cannot un-write a file already on disk, so the same phase
prunes the duplicates a box already grew: it asks the current pnpm which dir it
writes (`pnpm bin -g`) and removes the shadowed copy from the other. keyed on the
tool's own answer, the prune can never delete the live dir.

together they reduce two writers to ONE rather than arbitrate between them, which
`rule.forbid.two-writers-on-one-artifact` prefers wherever the reduction is
available. the PATH order stays, demoted to a tiebreak for boxes that still hold
duplicates.

⚠️ note which half is the real fix. the prune alone cleans the box and leaves
`@latest` free to regrow the fossils on the next apply — a repair that runs
forever and cures no cause. the pin is the cause; the prune is the cleanup.

⚠️ the prune found **three** fossils on the first run — `claude codex rhachet`.
`rhachet` was the 2026-08-02 defect, repaired by hand for one command four days
earlier. a fix applied per instance leaves the class open; only a phase that
enumerates closes it (`rule.require.clamp-edge-cases`).

## .disputes

no dispute is open.

## .see also
- `rule.forbid.two-writers-on-one-artifact` — the rule this noun serves
- `term=asset._.choice._.md` — what the shim's target is, and why it lives in `src/`
- `term=bin._.choice._.md` — the installed path the fallback names
- `rule.require.wrap-cli-in-skills` — why the `.agent/` caller exists at all
