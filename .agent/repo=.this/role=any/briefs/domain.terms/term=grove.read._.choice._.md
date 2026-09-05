# domain.term: read (in `grove.read`)

term.chosen   = read
term.kind     = verb
term.synonyms.forbidden:
- snap
- tail
- peek
- dump
- capture

## .what
the verb that names the act of a look at what a grove's duct currently holds — the pane's
visible output, returned to the caller without a change to the grove.

## .where
`rhx git.grove.read <name>` — the pure-read half of the `grove.send` / `grove.read` pair.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.read.sh    # the rhx dispatch surface
- src/bash_aliases.sh                                    # `git_alias_grove read` + ductwork

## .the pair it completes
`grove.send` writes into the duct; `grove.read` takes out of it. one verb per direction, so a
caller never has to guess which of the two mutates (`rule.prefer.symmetric-term-pairs`).

## .disputes
one dispute is **OPEN** on this word — see the reason file. contracts keep `read` meanwhile.

## .reason
see the ref-level cluster beside this choice:
- `term=grove.read._.choice.reason.md` — etymology, the open dispute, evidence
