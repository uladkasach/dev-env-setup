# F15 — the hibernate bundle measures tmux; it does not install it

## .the fork
- **install tmux** — `1.15.hibernate`'s upsert runs `pkg_install tmux`, so the duct signal's tool
  is present after `--what 1.15.hibernate` alone
- **measure tmux** — the check reads a duct only where a tmux server exists; an absent tmux binary
  is the true zero ducts, and `2.8.tmux` keeps the install

## .taken — measure
- a duct IS a tmux server, so on a box with no tmux there is no duct the check could miss; the
  verdict is complete with `seen ducts=0`
- the blind case — a server runs, and no swept socket answers — is caught by `pgrep`, not by the
  tmux binary, and holds loud (arm `moved`)
- `rule.require.bundles-own-their-dependencies` asks whether `--what <slug>` alone converges; it
  does, to a correct check. its two forbidden shapes (a silent assume that reads like a pass, a
  pointer-shaped error) are both absent

## .rework — clean
one `pkg_install tmux` line in the upsert, ahead of `set_artifacts`, and one arm.

## .confidence — 85%, and why it is low
a reviewer reads the rule as "every tool the code names", and the check does name `tmux`.

## .where
`idle-hibernate.sh` `read_ducts`; `configure.upsert.sh`

## .verdict
open — best-guessed at 5.1
