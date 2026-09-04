# domain.term: snapshot

term.chosen   = snapshot
term.kind     = noun
term.synonyms.forbidden:
- cronhook
- snap          (allowed ONLY as the by-hand alias `kitty.snap`; see .reason)
- snapper       (allowed ONLY for the WRITER, never for the record; see .reason)
- dump
- backup
- session-save

## .what
a read-only record of what a machine held at one moment, written for a human to
read back later. it captures a MAP, never contents: which windows existed, where
each stood, what ran there — not buffers, not scrollback, not env.

## .refs
- src/grove.provision/4.terminal/4.3.kitty/4.3.4.snapshot/     # the bundle
- src/machine/kitty_snap_lowbatt                              # the guard that takes one
- src/machine/kitty.snapshot.terminals.sh                     # the snapper itself
- .agent/repo=.this/role=any/skills/kitty.snapshot.terminals.sh  # a shim onto the above
- .agent/repo=.this/role=any/briefs/desktop/term/howto.restore-kitty-session.md
- src/machine/machine_usage_snapshot                          # the prior use, 1.7.usage

## .reason
see the ref-level cluster beside this choice:
- `term=snapshot._.choice.reason.md` — etymology, the rejected `cronhook`, evidence
