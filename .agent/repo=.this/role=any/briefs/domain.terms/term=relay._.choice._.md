# domain.term: relay

term.chosen   = relay
term.kind     = noun (and the verb it performs)
term.synonyms.forbidden:
- forward
- pipe (as a NOUN for this role — a pipe is a shell mechanism, not this concept)
- echo (as a NOUN — `echo` is one implementation, and the wrong one; see below)
- print
- surface

## .what

the carrier that moves remote-chosen bytes from a boundary to a human's terminal.

a **sink** makes bytes inert. a **relay** carries them. they are complements, never
synonyms: every relay must feed a sink, and a sink guards only the relays that feed it.

three facts a relay-writer owes:

1. **a relay feeds the sink AT CAPTURE** — a strip at print time guards one reader of a
   value that has several (`term=sink`, property 2)
2. **the VERB a relay uses is part of its guarantee** — zsh's builtin `echo` expands
   backslash escapes, so a name that spells an escape as the four printable characters
   `\`,`0`,`3`,`3` is authored into a REAL one by the relay itself. `printf '%s'` is
   inert in both shells. a byte sink cannot see this and correctly passes it
3. **a relay that drops the sink's exit status breaks the sink's promise** — the sink
   returns non-zero when a stage of it is absent, and a relay that discards that code
   reports a strip that never ran as one that succeeded

## .refs

- `.agent/repo=.this/role=any/skills/git.grove.operations.sh` — `_grove_relay_sunk`, the
  one relay both `_grove_err_sunk` and `_grove_ssh_sunk` share
- `src/ductwork.sh` — `duct.send`'s BUSY block, which relays `$held` with `printf`
- `src/ductwork.sh` — `__duct_pane_command`, a relay that sinks at the source

## .reason

see `term=relay._.choice.reason.md` — why `forward` and `echo` are forbidden, and the
2026-09-01 measurement that split the relay's SAFETY half from its SIGNAL half.
