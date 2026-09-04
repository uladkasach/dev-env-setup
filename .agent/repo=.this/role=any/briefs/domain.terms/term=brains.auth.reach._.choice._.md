# domain.term: brains.auth.reach

term.chosen   = brains.auth.reach
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

## 🛑 .why the `brains.auth.` prefix — and it is not cosmetic

this term arrived as a BARE `reach`, and a bare `reach` was already taken. `term=aws.reach`
holds it for a DIFFERENT concept in this same repo:

| term | what it names | kind |
|---|---|---|
| `aws.reach` | a box's ABILITY to act in an account — badge → profile → a call that answers | a capability chain |
| `brains.auth.reach` | an ADDRESS a token reports as its own | an identifier |

one word, two concepts, one repo — the exact overload `.readme.md`'s scope rule and
`rule.forbid.domain-term-synonyms` name. and `aws.reach` had already PREDICTED this collision:
it names `grove.reach` and `keyrack.reach` as clusters that would earn their own prefix the day
one is itemized. this is that day, for a fourth context.

⚠️ the FLAG stays `--reach`. a flag is namespaced by the command that takes it, so
`brains.auth.use --reach <email>` is unambiguous at the keyboard — the same way the term
`grove.provision` is spelled `rhx grove.provision` and the term `duct.uri.scope` is typed as a
bare `--on`. the prefix is what the GLOSSARY needs, not what a human types.

## .reason
see the ref-level cluster beside this choice:
- `term=brains.auth.reach._.choice.reason.md` — etymology, the settled `sub`/`slug` dispute, the
  prefix dispute, evidence
