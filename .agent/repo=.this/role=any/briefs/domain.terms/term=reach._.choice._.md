# domain.term: reach

term.chosen   = reach
term.kind     = noun
term.synonyms.forbidden:
- sub
- slug
- account-name
- handle

## .what
the email address an oauth token reports as its own identity — the name a claude subscription
is filed under, derived from the token rather than invented by a human.

## .refs
where the term is declared / used:
- src/brains.auth.sh                                  # `--reach`, `_brains_auth_is_reach`
- src/brains.auth.sh                                  # `_brains_auth_active_reach`, `_brains_auth_reaches`
- src/brains.auth.sh                                  # `_brains_auth_reach_from_flag`, `_brains_auth_has_reach`
- src/brains.auth.sh                                  # `_brains_auth_node_for_reach`
- .agent/repo=.this/role=any/skills/brains.auth.usage.sh
- .agent/repo=.this/role=any/skills/brains.auth.use.sh
- .agent/repo=.this/role=any/skills/brains.auth.set.sh
- .behavior/v2026_07_28.brain-budget-utilization/1.vision.yield.md   # the 2026-08-31 amendment

## .reason
see the ref-level cluster beside this choice:
- `term=reach._.choice.reason.md` — etymology, the settled `sub`/`slug` dispute, evidence
