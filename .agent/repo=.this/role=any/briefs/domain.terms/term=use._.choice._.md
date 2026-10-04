# domain.term: use

term.chosen   = use
term.kind     = verb
term.synonyms.forbidden:
- assume
- switch
- activate
- set
- export
- with

## .what
select X as the active context for what follows — a shell session's credentials, or a machine's
current config. selects; does not persist.

## .refs
the `use.*` family, ~30 declarations in `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh`:
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:45`     — `_use_aws_profile`, the shared implementation
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:58-72`  — aws profiles (`use.ahbode.prep`, `use.ehmpathy.camp`, …)
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:75-82`  — 3rd-party credentials (`use.ahbode.fastly`, `use.github.admin`)
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:85`     — tool config (`use.terraform.caching`)
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:88`     — machine network config (`use.mtu.1400`)
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:106-107`— machine keymap (`use.keymap.altswap`)
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh:340-341`— composed (`use.ahbode.prep.vpc`)
- `.agent/repo=.this/role=any/skills/use.apikeys.sh` — the skill form

## .reason
see the ref-level cluster beside this choice:
- `term=use._.choice.reason.md` — etymology, rejected synonyms, evidence
