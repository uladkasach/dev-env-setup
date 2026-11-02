# F6 — the badge: Roles Anywhere, via `credential_process`

## .the fork (mechanism — joint with ahbode/infrastructure#36)
- **A** IAM Roles Anywhere + AWS Private CA, short-lived mode
- **B** OIDC + `AssumeRoleWithWebIdentity`, via a self-run issuer

## .the fork (helper mode — ours)
- `credential-process` — in memory, per sdk call, no port, no daemon
- `serve` — an IMDSv2-shaped endpoint on 127.0.0.1
- `update` — a loop that writes `~/.aws/credentials`

## .taken: A + `credential-process`, and why at the time
- A: no service to operate (B needs a public JWKS endpoint we run); the wish's own cost table
  points here ($50/mo fleet-wide, vendor runs the CA)
- `credential-process`: the aws docs state `serve` answers *"any process … that can reach
  127.0.0.1"* — the EC2/IMDS hole, on the laptop with the human's rack. `update` adds a daemon
  and a second writer of `~/.aws/credentials` (`rule.forbid.two-writers-on-one-artifact`; today
  `5.6.aws` owns that file empty)
- the shape keeps every consumer unchanged: `[profile ambient]` swaps its SOURCE;
  `aws.reach.set` profiles use `source_profile = ambient` in place of
  `credential_source = Ec2InstanceMetadata`

## .rework
clean on the box half — if #36 picks B, `credential_process` names a different helper and the
file-mode boundary is the same. the CA itself is #36's.

## .confidence 70% — why not higher
- #36 has not chosen; this is a proposal to align on
- renewal (case=7) assumes the house role may issue its own next cert — an AWS-side grant only
  #36 can make. if it cannot, renewal needs a second actor, and that is a design change

## .where
case=4, case=6, case=7.

## .sources
- https://docs.aws.amazon.com/rolesanywhere/latest/userguide/credential-helper.html — modes,
  `serve` caveat, 12h max session, cert file reload since 1.2.0
- https://docs.aws.amazon.com/privateca/latest/userguide/short-lived-certificates.html — 7-day max

## .risk: risky
this is the AWS badge itself: a cert and private key on disk, signed into live sessions in the prep account. its file modes are the whole per-user wall (F15 holds the copy risk).