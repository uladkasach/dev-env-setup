# demo: 5.10.repos — two readers over one set, disagreed on a cut-partway clone

## .what

- 📜 measured 2026-08-14 on a fresh grove, thin link
- the upsert's skip-guard was `[[ -d "$into/.git" ]]`
- the verify's health test was `[[ -r "$into/.git/HEAD" ]]`
- one input broke both: a clone cut mid-flight lands `.git/` and never `HEAD`

## .the sequence

1. a clone is cut mid-flight; the upsert counts it `failed`, returns 1, the phase chain
   skips the verify
2. the human re-applies; the upsert's guard sees `.git/` and counts the corpse DONE —
   forever
3. the verify then refutes it and names a HAND STEP as the only fix: `rm -rf <dir>`,
   which no grove has a hand to take

## .the repair

- one reader (`grove_provision_5_10_repos_state`) replaces both guards
- it answers a three-valued state (`whole` | `half` | `absent`), never a boolean
- the upsert now SEES what the verify sees, so it repairs rather than skips

## .also settled here

- 📜 `gh ssh-key add` fix-text named a scope (`admin:public_key`) the box's own token
  cannot hold — see `rule.require.errors-name-the-fix`
- the state read is `.git/HEAD` readability, never `git -C … rev-parse` — three orgs of
  ~200 repos means ~600 forked calls on every plan against zero

## .see also

- `5.10.repos/_.sh` — the header this demo backs
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, the two-readers shape
- `rule.require.solve-at-cause` — the guard was the cause, the hand step the symptom
- `rule.require.bounded-probes-in-verifies` — why `.git/HEAD`, never a fork
