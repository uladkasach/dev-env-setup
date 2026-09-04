# domain.term: checkout

term.chosen   = checkout
term.kind     = noun
term.synonyms.forbidden:
- root
- repo root
- GROVE_ROOT
- source dir
- install dir
- work tree

## .what

the copy of this repo that sits on a box — the directory `grove.provision` runs from, and
the one every phase reads its assets out of. `src/` is a CHILD of it, never the whole.

## ⚠️ .a checkout is NOT reliably a git repo

`grove.bootstrap.sh` names two legitimate provenances, and only one of them carries a
`.git` (`term=provenance`):

| provenance | has `.git`? |
|---|---|
| cloned | yes |
| pushed by `grove.push` | **no**, by design — that is how a branch is proven on a grove before it merges |

so a checkout is a **directory**, not a repository. `5.12.rack` rests its whole design on
this: it names a separate throwaway `git init` root rather than assume the checkout is one,
and it must never "repair" a pushed checkout into a repo (`5.12.rack/_.sh:215`).

⇒ `clone` is therefore **not** a synonym on this list. it names one PROVENANCE of a
checkout, and `pushed` names the other. to forbid it would erase a distinction this repo
depends on.

## .refs

- `src/grove.provision/5.devtools/5.13.reach/configure.upsert.sh` — `checkout="$(dirname "$GROVE_SRC")"`
- `src/grove.provision/5.devtools/5.12.rack/_.sh:215` — why a checkout may hold no `.git`
- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh` — `CHECKOUT`, and the partial-checkout rungs
- `src/grove.provision._.sh:166` — exports `GROVE_SRC`, which is the `src/` dir INSIDE a checkout

## .reason

see the ref-level cluster beside this choice:

- `term=checkout._.choice.reason.md` — etymology, the `GROVE_SRC` overload that earned it
