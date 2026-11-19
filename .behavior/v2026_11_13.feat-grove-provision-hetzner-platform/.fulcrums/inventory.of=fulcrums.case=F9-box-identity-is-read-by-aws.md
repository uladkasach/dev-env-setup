# F9 — the box's own aws identity is read by `aws sts`, not keyrack

## .the fork

peer r1.b5 asks that rung 0b of `git.grove.auth.github.set` and the `ASKER` line of
`aws.reach.set` read the camp identity through keyrack, per
`rule.require.reach-credentials-through-keyrack`.

- **A — keep `aws sts get-caller-identity`** on the box's own `[default]` / `ambient` chain
- **B — route the read through keyrack**

## .taken

A.

- the rule's own test is *"who WRITES this?"*. the box identity is written by the
  platform: ec2's instance role (IMDS), or infra's IAM Roles Anywhere signer behind
  `[default]`'s endpoint on hetzner. keyrack writes no part of it and holds no slot for it
- the rule's measured harm is a raw read of a store keyrack fills (`~/.aws/sso/cache`
  against keyrack's `aws.config` vault), which answers the same for absent and present.
  here the raw read hits the one store that holds the fact, so it can fail, and does —
  T20 measured it red on the TagSession denial and green once infra granted it
- keyrack's own `aws.params` read rides the SAME chain: it decrypts through the
  `[default]` identity. a keyrack read cannot be more live than the identity under it,
  so B would ask the derived fact to vouch for its source

## .rework

clean — two call sites, each one line.

## .confidence — 85%

- the rule's text said *"never through a raw aws call"* without the carve-out. the carve-out
  follows from its own `.the tell`, and the brief now states it (`.the one carve-out the
  tell implies`)

## .where

`git.grove.auth.github.set.sh` rung 0b · `aws.reach.set.sh` `ASKER`.

## .verdict

open — disputed to the reviewer with this entry.
