# domain.term: main

term.chosen   = main
term.kind     = noun
term.synonyms.forbidden:
- global (names a scope; `main` names a place — the word `--version global` once used)
- master (the retired git default; this repo sets `init.defaultBranch main`)
- trunk (svn jargon, and it never appears in a command a human types here)
- root (ambiguous — a repo root, a filesystem root, and a superuser all claim it)

## .what
the trunk of a repo: the branch every tree is carved from, and the one checkout that
tracks it. `main` is what a tree is NOT — the pair is the whole where-does-this-code-live
axis on a machine.

## .the two readings, and why they are one term
- **the branch** — `origin/main`, the ref a tree branches off (`git tree set --from main`)
- **the checkout** — `~/git/more/dev-env-setup`, the clone that sits on that branch

these are not two concepts. the main checkout is DEFINED as the one that tracks main; to
split them would mint a second word for one lineage. a reader who says "pull main" and a
reader who says "cd to main" name the same place, reached two ways.

## .the third use — RESOLVED 2026-07-28, the day it was flagged
this section once read: *"`duct://grove-1:main` … is a DEFAULT NAME, not the trunk … a
label, so no contract rests on it as the trunk."* that was a caveat filed in place of a
fix — the overload was named, then left in force.

the human refused it the same day:

> duct://grove-1:main, sounds like we should change :main -> :mechanic ? i.e., cause by
> default we open the mechanic

the grove duct is now `grove-1:main/mechanic`, per ductwork's declared `<tree>/<role>`
session grammar. so `main` in that address is **this term, used correctly** — the grove's
src sits in the MAIN CHECKOUT, and `main/mechanic` reads as "the mechanic role, in the main
checkout". no overload is left to caveat.

termwork's base tab default (`main` when no `--tab`/`--for` is given) is untouched and
remains a bare label — it names no tree and no role, so it makes no claim on this term.

> **the lesson: a documented overload is still an overload.** to record a collision in the
> glossary is not to resolve it; the glossary is where a resolution is *recorded*, not
> where one is *substituted for*.

## .refs
where the term is declared / used:
- src/bash_aliases.sh                       # `git tree set --from main|this`, `git release main`
- src/bash_aliases.sh                       # git.repo.pull — checks out main
- src/grove.provision/2.shell/2.2.git/configure.upsert.sh  # init.defaultBranch main
- .agent/repo=.this/role=any/skills/grove.provision.sh   # `--from main|tree` (proposed)

## .reason
see the ref-level cluster beside this choice:
- `term=main._.choice.reason.md` — etymology, the `--version global` retirement, evidence
