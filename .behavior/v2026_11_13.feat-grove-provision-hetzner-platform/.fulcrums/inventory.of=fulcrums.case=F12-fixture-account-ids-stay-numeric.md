# F12 — a play's fixture account id stays a numeric dummy, never `<acct>`

## .the fork

peer r1.b1 (i001) reads the twelve-digit ids in four new plays as dox, and asks for `<acct>`.

- **A — keep the dummy values; dispute with the guard's own allow-list**
- **B — replace each with `<acct>`**

## .taken

A.

- every id in those plays is one of the five values `dox.verify` allows BY VALUE as fixtures
  (`123456789012`, `012345678901`, `111122223333`, `999999999999`, `000000000000`;
  `.agent/repo=.this/role=any/skills/dox.verify.sh`, its fixture allow-list). none names a real account
- the input is PARSED: `aws.reach.set` refuses an `--account` that is not `^[0-9]{12}$`, so `<acct>`
  would turn each arm into a refusal and the play would prove the wrong branch
- the `<acct>` the reviewer cites in `prove.gate-names-what-it-refuses` sits inside aws's own
  error TEXT, which no parser reads — prose is where a placeholder belongs
- `rhx dox.verify` → `dox: none found across 1646 tracked files ✔`

## .rework

clean — a swap to placeholders is a sed, should the human rule B.

## .confidence — 95%

## .where

`prove.hetzner-default-profile-survives`, `prove.carried-tree-serves-reach`,
`prove.keys-verify-names-each-verdict` and their snaps.

## .verdict

open — disputed to the reviewer with this entry.
