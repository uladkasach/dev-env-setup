# domain.term.choice.reason: grove.restore

## .etymology

`restore` is the word every backup system pairs with backup, and the commander's own word for a
new grove's first act. the pair reads at a glance (`rule.prefer.symmetric-term-pairs`).

the skill sits at `grove.backup.restore`: the noun first, then the verb, so `<TAB>` after
`grove.backup.` shows both its operations (`rule.require.treestruct`).

chosen over:
- `recover` — names the outcome a human hopes for, not the act. a restore that lands a diverged
  branch aside under `<grove>/<branch>` has restored; whether the human has recovered is theirs
- `rehydrate` — jargon for a cache refill; it hides that bytes move from a bucket
- `download` — names the transport, and `term=grove.pull` already forbids it
- `unpack` — names one step. a restore also grafts refs, relinks worktrees, and lays home files
  only where absent. `unpack` stays the name of the tar step alone (`restore_unpack`)

## .disputes
none yet.

## .evidence

- the round-trip play backs up a fixture grove into a dir bucket, then restores each unit kind
  onto a fresh seat; three snaps pin the result
- narrative: the old grove holds a tree with an unpushed commit and a live clone conversation;
  the new grove runs one restore; both are whole, and a newer local branch never moves back

## .invariants

- a restore never overwrites live work: a ref only fast-forwards, a home file lands only where
  absent, a diverged branch lands aside
- a restore never lays `~/.rhachet/keyrack/`: it is sealed to the dead grove's own key
- a restore is idempotent: a second run over the same backup changes naught
