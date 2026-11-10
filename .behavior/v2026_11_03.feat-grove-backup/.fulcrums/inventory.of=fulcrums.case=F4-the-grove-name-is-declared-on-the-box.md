# F4 — the grove name is declared on the box

## .the fork

the key needs `grove=<slug>`. no grove knows its own name today: the name lives only in the laptop
registry (`bash_aliases.sh:3090`, `_git_grove_get`); ec2 instances carry no `Name` tag
(`bash_aliases.sh:3119-3132`); no `/etc/grove/name`, no env var.

- **A (taken)** — infra declares it at `/etc/grove/name`, beside `/etc/grove/platform`, which its
  hetzner bootstrap already writes (`src/grove.env.sh:282-338` reads that file)
- **B** — read it from the tailnet self hostname (infra joins with `--hostname=<grove>`)
- **C** — the laptop pushes it at `git.grove.provision boot`

## .why A

- a declaration, never an inference (`rule.require.judge-declared-state-not-live-state`); the same
  shape `/etc/grove/platform` set
- B couples the backup key to the tailnet; a box off the tailnet would back up as nobody
- C leaves a grove that infra rebuilds without the laptop unnamed until a human acts

## .the loud default

absent `/etc/grove/name` → the agent refuses to put, status `✗ FAILED`, cause `grove name
undeclared`, and names the owed infra step. never a guessed name: two groves under one guess
would overwrite each other's `date=` key.

## .rework — clean

one read function.

## .confidence — 70%

an infra change, so an owed item; B would ship sooner.

## .risk — safe

- **no credential**: a grove name is a public-shaped identifier in a root-owned file, beside
  `/etc/grove/platform`
- **no new prod write**: the name only picks the `grove=<slug>` prefix of the feature's own put.
  an absent name refuses the put (the loud default above); a duplicated name would collide two
  groves' `date=` keys, but bucket versions keep every overwritten object and the grant holds no
  delete, so naught is lost

## .verdict

—
