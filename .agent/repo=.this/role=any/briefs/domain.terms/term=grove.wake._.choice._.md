# domain.term: wake

term.chosen   = grove.wake
term.kind     = verb
term.synonyms.forbidden:
- start        # aws's api verb for the box alone; a wake drives the whole reach path
- boot         # implies a cold power-on; a wake may resume instead
- resume       # names one mechanism (hibernate-resume), not the outcome
- provision    # stands up a machine that does not exist; a wake needs one that does

## .what
drive a grove to reachable: its egress up, its box up, its duct able to relay, its
alias written. idempotent — a wake of a reachable grove is a no-op.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.wake.sh   # the portable wake
- src/bash_aliases.sh                                   # `git grove wake` dispatch

## .reason
see the ref-level cluster beside this choice:
- `term=grove.wake._.choice.reason.md` — etymology, the start/boot disputes, evidence
