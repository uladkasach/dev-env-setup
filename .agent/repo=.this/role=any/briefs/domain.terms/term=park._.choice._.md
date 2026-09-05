# domain.term: park

term.chosen   = park
term.kind     = verb
term.synonyms.forbidden:
- stash
- save
- store
- backup
- archive

## .what
file the live account's refresh token into the keyrack, so the account survives a swap that is
about to overwrite the only copy it has.

## .refs
where the term is declared / used:
- src/grove.provision/2.shell/2.7.aliases/brains.auth.sh   # `_brains_auth_park_read`  — read the live token out, write nowhere
- src/grove.provision/2.shell/2.7.aliases/brains.auth.sh   # `_brains_auth_park_file`  — file it into the keyrack
- src/grove.provision/2.shell/2.7.aliases/brains.auth.sh   # `_brains_auth_park_or_strand` — the failure fork
- src/grove.provision/2.shell/2.7.aliases/brains.auth.sh   # `_brains_auth_bak_strands` — the guard that refuses a swap mid-strand

## .reason
see the ref-level cluster beside this choice:
- `term=park._.choice.reason.md` — etymology, the `stash`/`save` judgment, evidence, and the
  `park` / `strand` pair
