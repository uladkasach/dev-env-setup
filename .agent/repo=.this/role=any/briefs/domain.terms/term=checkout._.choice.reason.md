# domain.term.choice.reason: checkout

## .etymology

git's own word for a working copy on disk, and the word 40+ files of this repo already
speak — in `src/`, in the skills, in the playbooks, in the briefs. it was canonical in
practice long before it was written down here. this cluster records a word already in use;
it mints none.

it is chosen over **`root`** because a bare `root` is ambiguous three ways in this repo:

| which root? | what it actually is |
|---|---|
| the checkout | the repo copy on the box |
| the git root | what rhachet's cli demands, and `5.12.rack` supplies EMPTY on purpose (`term=keyrack.gitroot`) |
| the bundle-tree root | `src/grove.provision/_.sh`, the dispatcher at depth 0 |

a term whose unqualified form names three things is an overload, and
`rule.require.ubiqlang` forbids exactly that. `checkout` names one.

## ⚠️ .the overload that earned this cluster — measured 2026-08-12

the glossary held no entry for this concept, so a skill reached for its own word — and
picked one already taken.

the bundle runtime exports `GROVE_SRC`, and there it is the **`src/` directory**:

```sh
# src/grove.provision._.sh:166
export GROVE_SRC="$SRC"
```

so every phase reaches the checkout with ONE dirname:

```sh
# 5.13.reach/configure.upsert.sh
local checkout; checkout="$(dirname "$GROVE_SRC")"
```

`git.grove.ready.verify` then bound the SAME name to the **entrypoint file**, one level deeper,
and so needed two:

```sh
GROVE_SRC='~/git/more/dev-env-setup/src/grove.provision._.sh'
GROVE_ROOT="$(dirname "$(dirname "$GROVE_SRC")")"
```

both files computed the right directory. each was internally consistent, so no run broke
and no check reddened — which is what makes this the expensive kind. the cost is carried by
a **reader**: `dirname "$GROVE_SRC"` is the checkout in one file and `src/` in the other,
so anyone who moves the idiom across lands one level off, silently.

⇒ the repair was to name both for what they are — `CHECKOUT` (the copy on the box) and
`GROVE_ENTRY` (the one entrypoint) — and to write this cluster, so the next author finds
the word instead of a second coinage of `GROVE_ROOT`.

## .the evidence this is one concept, not two

a single grep answers it. `checkout` appears across every layer of the repo, and always for
the same thing — the repo copy on a box:

- `src/grove.provision._.sh:256` — *"confirm the checkout is complete, or re-push the worktree"*
- `src/grove.provision/1.system/1.8.tmpfiles/provision.verify.sh:36` — *"the installed $name DIFFERS from this checkout"*
- `src/git-credential-keyrack.sh:240` — *"THIS repo's checkout — it owns `.agent/keyrack.yml`"*
- `src/grove.provision/3.cosmic/3.2.theme/configure.upsert.sh:9` — *"the same run applied this checkout's terminal config"*

no competing word does that work. the concept was settled; only its record was absent.

## .disputes

none raised.

⚠️ `clone` reads like a candidate and is not one. it names a **provenance** of a checkout,
and `pushed` names the other (`term=provenance`: *"cloned and pushed exhaust the ways a src
reaches a machine in this repo"*). the two are not interchangeable, and the difference is
load-bearing: a pushed checkout carries no `.git`, which is precisely why `5.12.rack` names
a separate throwaway git root rather than trust the checkout to be a repo. to record
`clone` as a forbidden synonym would collapse a distinction the code depends on.
