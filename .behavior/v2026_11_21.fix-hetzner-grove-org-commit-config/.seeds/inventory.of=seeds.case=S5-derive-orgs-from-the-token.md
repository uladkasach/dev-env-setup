# S5 — derive the orgs from the grove's token, and apply them

## .said
that looks like a code smell; the one-command grant you type (rhx git.grove.auth.commit.set <grove> --mode apply).

you can just check what orgs the github token on that cloud grove has and auto apply the orgs from that.

## .settled
- a cloud grove's commit orgs are the orgs its github token can push to — read on the box, never a declared table
- `5.26.commitorgs` writes `allowed` for each such org the meter holds unset; a block stays as the human set it
- no hand grant command remains: `git.grove.auth.commit.set` and the boot relay are removed
- a local grove still declines: its meter is the human's own choice, set at his own terminal

## .landed
| artifact | change |
|---|---|
| `src/grove.provision/5.devtools/5.26.commitorgs/` | the token read, `configure.upsert`, a verify that grades each token org |
| `git.grove.auth.commit.set.sh`, the boot relay | removed |
| `.fulcrums/…F1…`, `…F2…`, `…F15…` | verdicts recorded |
| seeds S1–S4 | superseded |
| `howdoes.a-grove-crew-clears-the-org-commit-gate` | rewritten for the token-derived grant |
