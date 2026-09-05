# domain.term: exemption

term.chosen   = exemption
term.kind     = noun
term.synonyms.forbidden:
- escape hatch
- escape valve
- workaround
- bypass
- override

## .what

a sanctioned departure from a default, gated on a named **trigger** — the condition
that must hold for the departure to be earned.

`--bare` on `git.grove.send` is the worked example: the duct is the default, and
`--bare` leaves it. it is legitimate, and legitimate only while its trigger fires
("no tmux yet", "the duct is broken").

## .what it is NOT

- a **workaround** — that is an unsanctioned dodge of a defect
  (`rule.require.solve-at-cause` forbids it). an exemption is declared and allowed.
- a **default** — an exemption typed on every call has ceased to be an exemption
  (`rule.forbid.exemption-as-habit`).

## .refs

- `.agent/repo=.this/role=any/briefs/evidence/rule.require.exemptions-name-their-trigger.md`
- `.agent/repo=.this/role=any/briefs/evidence/rule.forbid.exemption-as-habit.md`
- `.agent/repo=.this/role=any/skills/git.grove.send.sh`   # the `--why` trigger guard

## .reason

see the ref-level cluster beside this choice:
- `term=exemption._.choice.reason.md` — etymology, the escape-hatch dispute
