# F8 — the badge sits on the camper seat only

## .the fork
- **A** both seats get a cert (as on EC2, where every uid reads IMDS)
- **B** camper only; ground's `5.6.aws` declines with 🌙 *"no badge for the ground seat of a
  house grove"*

## .taken: B, and why at the time
- every AWS call a crew makes runs on camper; ground converges the box, and its only AWS reads
  (`5.12.rack` ssm) are already gated off for non-ec2
- one cert per grove halves what a renewal must keep alive and what a leak exposes
- EC2's "every uid" is the hole, not a feature to mirror

## .rework
clean — a second cert is additive.

## .confidence 60% — why low
unmeasured: whether any ground-seat bundle or play calls `aws` for a reason besides the rack.
the execution stone must grep for it.

## .measured at `has-questioned-questions`
the ground seat is NOT free of aws calls: `5.6.aws/configure.verify.sh:51`,
`5.13.reach/configure.verify.sh:20`, and `5.16.keys/configure.verify.sh:70` each probe
`--profile ambient` on every seat. so F8 owes three declines on the house ground — 🌙 *"this
seat holds no badge, by design"* — and a clamp that each reads 🌙, never ✋.

## .where
case=4.
