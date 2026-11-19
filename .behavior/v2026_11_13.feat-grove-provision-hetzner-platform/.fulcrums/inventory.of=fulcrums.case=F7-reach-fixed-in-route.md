# F7 — tailnet reach is fixed in this route

## .the fork
- **A (taken):** fix `git.grove.wake` and `git.grove.trust.gen` for a tailnet grove here, since S8's boot runs through both
- **B:** keep reach out of scope (F3, S2), and halt the boot at step 1

## .why A
S8 owes a boot on the hetzner box, and step 1 calls wake and trust. F3 kept reach out of scope while no outcome depended on it. S8 changes that, and a halt on a gap this seat can close is a deferral.

## .rework — clean
two additive arms, both gated on a registry host that is not localhost. an ec2 grove takes neither.

## .confidence — 85%

## .where
- `.agent/repo=.this/role=any/skills/git.grove.wake.sh` — the tailnet arm
- `.agent/repo=.this/role=any/skills/git.grove.trust.gen.sh` — direct scan, pinned attestation, append of absent types only
- clamp: `.play/permanent/prove.tailnet-grove-is-reached-and-trusted.play.sh`

## .verdict
open
