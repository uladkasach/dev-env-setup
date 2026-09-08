# domain.term: push

term.chosen   = grove.push
term.kind     = verb
term.synonyms.forbidden:
- upload
- copy-to
- deploy
- ship

## .what
move content from here to a grove.

## 🛑 .the SUBJECT is the working TREE, never a commit

this is the split the word turns on, and the one its `git.commit.push` precedent hides.

| verb | what it moves | what a dirty tree does |
|---|---|---|
| `git.commit.push` | COMMITS — what git has recorded | ignored; git never saw it |
| `grove.push` | the **working tree**, over rsync | **it goes**, uncommitted and all |

⇒ the two verbs share a word and take OPPOSITE subjects. `commit.push` cannot carry work git has
not recorded; `grove.push --from .` carries no other kind.

📜 measured 2026-09-07, and the cost was a second author's. a peer held ~280 uncommitted lines of
an in-flight nvim breaker in this tree. a `git.grove.push <g> --from . --mode apply`, typed to
deploy a DIFFERENT change, carried their unfinished experiment to both seats of a grove — where
it applied. verified after the fact, never before:

```
grove-ahbode-v20260901:  grep -c count_extmarks ~/.config/nvim/init.lua  →  3
```

the push's own output named every file it would send. no reader asked whether their author had
finished with them.

⇒ **`--from .` is a claim about a PATH and says none of the STATE at that path.** before a push,
read `git status` — the tree is the payload, so its dirt is the payload too.

⚠️ and the precedent below is the trap, not the guide. it was cited for the WORD and reads as a
warrant for the SEMANTICS.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.push.sh
- src/bash_aliases.sh                  # git.commit.push — the NAME's precedent, and the
                                       # opposite of its subject; see the split above

## .reason
see the ref-level cluster beside this choice:
- `term=grove.push._.choice.reason.md` — etymology, disputes, evidence
