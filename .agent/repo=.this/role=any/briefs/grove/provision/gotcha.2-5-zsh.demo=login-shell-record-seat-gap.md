# gotcha.2-5-zsh.demo=login-shell-record-seat-gap

## .what

the dated measurements behind `2.5.zsh/provision.upsert.sh`'s seat-record write, its
seeded-empty-`.zshrc` step, and its year-long 🌙/✋ correction.

## m1 — a write of `$USER` alone leaves the camper's record untouched

measured 2026-08-11 and again 2026-08-12, one box, one pam, one key-only auth:

| seat | record | how |
|---|---|---|
| ground | `/usr/bin/zsh` | `sudo chsh` SUCCEEDED — this seat has sudo |
| camper | `/bin/bash` | never ATTEMPTED — that seat has none |

the camper's record was never asked for, not refused. the phase named only the user who
happened to invoke it. the seat that could write the record was not the seat that
needed it. `ssh camper '<cmd>'` runs the login-shell RECORD. a bash record means
`bash -c`, which reads no startup file at all — not `.bashrc` (early return), not
`.profile` (login only), not `.zshenv` (zsh unused). every program-borne call onto the
seat that does the jobs got a bare PATH.

## m2 — a record with no startup file eats the duct pane's first command

measured 2026-08-25, a from-scratch grove:

```
ground apply → the camper's record becomes /usr/bin/zsh
             → the camper's ~/.zshrc is still absent
camper duct  → tmux opens the RECORD's shell
             → zsh finds no startup file
             → `zsh-newuser-install` draws its menu
```

a duct is tmux. that menu becomes the pane's reader — it eats the next command sent
down (`term=eat`). the pane showed it verbatim:

```
--- Type one of the keys in parentheses --- { bash …/grove.provision._.sh
zsh: parse error near `}'
```

the `{` was consumed as the keypress; the remainder was a syntax error. the reply's
rc file was never written; the caller returned 97.

## m3 — a 🌙 stood for a year, and the 🌙 was the defect

the block read: the claim is "an INTERACTIVE login lands in zsh". by that claim the
`.bash_profile` hand-off satisfies it. that sentence is true about a HUMAN and false about the box:

| caller | reaches the hand-off? |
|---|---|
| a human's login | ✔ hands off to zsh |
| `ssh seat '<cmd>'` | stays `bash -c`, reads NO startup file |
| a cron, a jest child | same |

the callers it does NOT reach are the ones a grove runs on. a 🌙 raises no alarm.
nobody re-read it (`term=decline._.choice.reason.md` carries this as its own ⚠️) — it is
a ✋ now, since a box must be reachable NON-INTERACTIVELY after one apply
(`rule.require.one-command-provision`).

## .see also

- `rule.require.seam-claims-have-an-owner` — the seat-gap fix in m1 and m3
- `rule.require.one-command-provision` — why m3's 🌙 became a ✋
- `define.provision-defect-shapes` — the "DARKEST corner" this hazard occupies
- `term=eat` / `term=decline` — the vocabulary m2 and m3 prove
