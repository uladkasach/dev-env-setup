# F16 — the token's push scope bounds the commit orgs; the own-org rule bounds account reach

## .the fork

peer round i004 of 5.3 (r012, blocker 5) read `rule.require.a-grove-reaches-its-own-org-only` as a
bound on the commit meter: an ahbode grove's bundle allows every org its token can push to, with no
own-org or opt-in check, and row 6b grants `acme` from an `--org ahbode` entry.

the options:

- **own-org filter** — allow only the grove's own org plus enumerated opt-ins; every other token
  org stays unset, and its crews are refused at the done gate
- **the token's scope is the bound** — allow each org the token can push to, as seed S5 settled

## .taken

the token's scope is the bound. three reasons:

1. **the rule bounds a different power.** its three clauses and its clamp govern per-org REACH
   tables: aws accounts, keyrack rows, profiles, clone sets. a reach row grants a power the box
   would not otherwise hold. the commit meter grants none: it is a local gate in front of a push
   the token already authorizes. a crew that commits for an org the token cannot push to is
   stopped at the push by github itself, whatever the meter says
2. **the scope is set where the token is minted.** the org a token may push to is decided by the
   human who mints it, on github, org by org. that IS the enumerated opt-in, held at its source; a
   second list here would be a copy of it, which S5 named the defect
3. **seed S5 ruled this fork.** the wisher's settlement: a cloud grove's commit orgs are the orgs
   its github token can push to, read on the box, never a declared table

the removed clamp (an org-scoped-rows arm for 5.26) graded the declared table this branch carried
before S5. against `origin/main` the org-scoped-rows play is unchanged: main never held that arm.

## .rework

clean: an own-org filter is one `grove_provision_5_26_commitorgs_is_listed` test over the token
orgs in `configure.upsert`, plus a clamp arm. no caller leans on the wider set.

## .confidence

85%. the gap: a token minted wider than one grove's work would let that grove's crews commit for
each org it reaches. the remedy for that sits at the mint, where the scope is chosen.

## .where

`src/grove.provision/5.devtools/5.26.commitorgs/configure.upsert.sh`,
`.agent/repo=.this/role=any/briefs/creds/rule.require.a-grove-reaches-its-own-org-only.md`.

## .verdict

open: disputed in 5.3 peer round i004 (r012), for the council.
