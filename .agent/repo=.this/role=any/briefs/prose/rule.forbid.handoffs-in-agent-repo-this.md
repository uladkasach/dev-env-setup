# rule.forbid.handoffs-in-agent-repo-this

## .what

**a handoff never lives under `.agent/repo=.this/`.** it lives in the route that raised it:
`.behavior/<route>/handoff.<owner>.<subject>.md`.

## .why

- **a handoff is temporary.** it is a live ask of another owner, and it ends the day that owner
  lands it. `.agent/repo=.this/` holds what stays true: rules, howtos, terms, invariants
- **the route is its home.** the route raised the ask, holds the evidence beside it, and closes
  with it. outside the route, the ask outlives its context and reads as settled doctrine
- **it pollutes the boot.** every brief under `.agent/repo=.this/` costs a path line in every
  session, so a stale ask taxes every reader long after it settled

## .the test

> will this file be wrong, or moot, once another owner acts?

- yes → it is a handoff. it goes in the route
- no → it may be a brief

## .what a durable brief may say about the ask

the durable FACT, in its own words: the bar, who owns it, what holds today. never a pointer to the
route's handoff file, which leaves when the route closes.

## .enforcement

- a `handoff.*` file under `.agent/repo=.this/` = **blocker**; move it to the route that raised it
- a brief that cites a route's handoff as the ground for a durable claim = **blocker**

## .see also

- `gotcha.my-own-note-became-my-evidence` — a live ask, read later as a fact
