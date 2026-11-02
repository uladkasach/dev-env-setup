# F11 — the mint is an election plus a bundle, never a skill that writes `/etc`

## .the fork
- **A** `git.grove.house.set` creates the users, the sshd unit, the sudoers drop-in, and the
  slice caps itself
- **B** `git.grove.house.set` writes ONE election file (the grove declared, under a root-owned
  dir), then drives `grove.provision --what <n>.house` on the host; the BUNDLE converges every
  declared house grove. the skill also owns the supervisor-side registry rows, which are not box
  config

## .taken: B, and why at the time
- found at the self review `has-questioned-requirements`. the draft vision held A, which is a
  second door onto box state: `rule.require.grove-provision-as-the-only-entrypoint` and
  `rule.require.repo-as-source-of-truth` each grade a box change applied off the entrypoint a
  blocker
- the repo already paved B: `machine.openhours.optin.set` writes one file — *"it writes ONE file
  — the election. the bundle installs the timer"* — and `5.18.openhours` converges to it
  (`rule.require.optin-bundles-converge-to-their-flag`)
- B gives the bundle a `*.verify`, so a drifted house grove (inventory row 3) is a plain re-apply
- the election dir doubles as F5's marker: a login whose user is a declared house seat reads
  `house@unix`. one root-owned fact, two readers

## .rework
clean — no code exists yet.

## .confidence 85% — why not higher
- the bundle's slug and depth are unset (`<n>.house`); `1.system` vs `2.shell` is a real
  question, since it touches users, sshd, and cgroups at once
- a bundle that converges OTHER users' accounts on the host is a new shape here; every extant
  bundle converges its own seat or the box. it is box-wide, so it sits on the host's root path —
  but the shape deserves a peer read at the blueprint

## .where
case=1 `[t0]`; F5.

## .risk: risky
the host bundle the mint drives writes the users, the sudoers drop-in, the sshd unit, and the seat authorized_keys onto the human laptop. those are credentials and a root grant (F3, F4), so the mint path carries their grade.