# domain.term.choice.reason: shadow

## .etymology

from the unix sense already in the reader's hands: a binary earlier on `PATH` **shadows** a later
one, the way `/usr/local/bin/python` shadows `/usr/bin/python`. shells document it with this word,
and `which -a` exists precisely to reveal it.

so the term is **discovered, not invented** — it already lived in the domain (the shell) before this
repo named it. that is the strongest kind of term: a reader who has never opened this repo already
knows what a shadowed binary is.

the eclipse metaphor carries the exact property that matters: **the shadowed thing is still there,
intact, and idle.** the pinned pnpm copy is not corrupted or removed. it is simply never reached.
no other candidate word carries that.

## .why each synonym is forbidden

| synonym | why rejected |
|---------|--------------|
| `duplicate` | names the **count** (two installs), which is the harmless part. two installs where the pin still wins is not the hazard; the word would flag a non-problem and miss the real one |
| `stale install` | implies **age** is the fault. the shadow is often *newer* than the pin — claude's native-installer migration installs a fresh copy. calling it stale points the fix at the wrong axis (upgrade it) instead of the right one (remove it) |
| `rogue install` | implies **intent**. no one installed it maliciously; it arrives from an honest `npm i -g` or a vendor auto-migration. a blame word sends the reader to look for a culprit instead of a PATH order |
| `version conflict` | implies the two installs **contend** and something breaks loudly. they do not contend — that is the whole hazard. one silently wins |
| `orphan` | already carries a distinct sense in this repo's vocabulary (an orphaned *process*, see `hazard.idle-process-leak-crosses-the-swap-cliff.md`). overloaded onto installs, it collides two unrelated concepts |

## .evidence

**the discovery move: five whys on the observed symptom.** *"claude behaves oddly around hooks"*
→ why? → hook output is truncated → why? → the resolved claude is past v2.1.87 → why, when the repo
pins v2.1.87? → because a different binary resolves first → why does that go unnoticed? → **because
no step ever compares the resolved binary to the pin.** the buried cause is a PATH-precedence fact,
not a version fact — which is what fixed the word choice.

**the audit that proved it recurs** (`hazard.claude-shadowed-by-npm-global.md`): claude-code was
found npm-global under **five** fnm node versions — v20.12.2, v20.18.1, v22.14.0, v22.21.0,
v24.14.0 — while the repo believed a single pnpm copy was in use. the shadow is installed *per node
version*, so it accumulates, and `fnm use` to any of them surfaces a different claude.

**the three-way race that makes it silent** (all three must hold, and each looks harmless alone):

1. no `alias claude=` exists — the "pin" was only ever *"the pnpm copy happens to be first"*
2. `eval "$(fnm env --use-on-cd)"` puts `/run/user/$UID/fnm_multishells/*/bin` near the front
3. the `PNPM_HOME` prepend in `src/zshrc.sh` is guarded by a `case ":$PATH:"` check, so when
   `~/.local/share/pnpm` is already inherited *anywhere* in PATH the prepend is a no-op — and it
   stays **behind** fnm's bin forever

**the term earns its keep in the fix.** because the concept is named, the guard could be named for
it (`prune_claude_code_shadows`) and the verify step could name the cause in its own error text.
an unnamed hazard would have produced a nameless "just reinstall it" fix.

## .disputes

no dispute open.

`duplicate` was the first word reached for in conversation and **rejected on the count-vs-precedence
distinction** recorded above, rather than disputed. should a future traveler judge that this repo's
readers are better served by a plainer word, open a dated dispute here rather than a quiet rename.

## .invariants

- a contract (function name, brief title, error message, doc heading) that names this concept uses
  **shadow**
- a shadow is defined by **PATH precedence over the pinned install**, never by mere coexistence —
  text that describes it purely as "two copies installed" describes something else
- any text that names a shadow must also name **why it is silent**; a shadow described without its
  silence reads as a routine cleanup chore and loses the reason the guard exists
- the remedy for a shadow is **removal at its source**, never a PATH reorder — a reorder is undone
  by the next shell (see `prune`, and `rule.require.solve-at-cause`)
