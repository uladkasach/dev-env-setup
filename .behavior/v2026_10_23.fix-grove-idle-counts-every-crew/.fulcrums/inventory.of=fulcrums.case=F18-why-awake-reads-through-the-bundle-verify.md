# F18 — "why is it awake?" reads through the bundle's verify, never a command of its own

## .the fork
- **the verify** — `rhx grove.provision --what 1.15.hibernate --mode plan` shows the last tick,
  its age, the last sleep, and on a drifted box a `⇒ now:` line that says what the box risks
- **a reader skill** — a new `rhx` skill that prints the two records alone, exit 0, with no
  provision verb in its name (the r010 i007 ask)

## .taken — the verify
- a plan is a survey: it runs every verify and no upsert (`repo.overview`), so it is the
  read-only answer by construction, and on any box
- a second command that reads the same two records is a second path to one fact
  (`rule.require.grove-provision-as-the-only-entrypoint`); the two would drift on the first
  change to the record shape
- the exit 1 on a drifted box is correct: a box that does not match its declaration has failed to
  converge, and the `⇒ now:` line beside the ✋ says whether a crew is at risk
- what the ask names as friction is real — the command must be known. the remedy is the record
  path in the check's header and the verify's name in the PR, not a second reader

## .rework — clean
a thin skill over `grove_provision_1_15_hibernate_record_lines` and the risk reader, if a
commander still asks for one after the PR.

## .confidence — 80%, and why it is not higher
the ask comes from a reviewer who ran the plan and found it opaque on first read; a commander may
too. the risk line answers the sharper half of that.

## .where
`configure.verify.sh`, `_.sh` (`grove_provision_1_15_hibernate_risk`)

## .verdict
best-guessed at 5.1, flagged in the PR
