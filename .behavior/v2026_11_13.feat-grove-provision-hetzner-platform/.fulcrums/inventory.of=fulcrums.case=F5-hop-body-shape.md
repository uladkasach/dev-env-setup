# F5 — hetzner hops carry ec2's body + an endpoint line

## .the fork

how a hop on hetzner reaches the box's own identity before it assumes the target role.

- **A — endpoint line.** `role_arn` + `credential_source = Ec2InstanceMetadata` + `ec2_metadata_service_endpoint = <read from [default]>` + `region`
- **B — the wish's shape.** `role_arn` + `source_profile = default` + `region`

## .taken

A, against the wish's literal text — now on a measurement, not a recall.

- measured on the hetzner grove's camper seat: a copy of the live config, one
  probe profile per shape, both on the `ahbode.prep` hop's role, one
  `aws sts get-caller-identity` each
  - A → rc 0
  - B → rc 255, `The source profile "default" must have credentials.`
- the cause: a `source_profile` yields credentials only through the profile
  providers (static keys, `credential_process`, sso, web identity). infra's
  `[default]` holds a region and an endpoint, no credential, so B cannot start
- A is ec2's body plus one derived line, so both grove platforms share one hop
  shape and one code path
- A never names `[default]` as a dependency of the hop, so a re-run of infra's
  identity skill cannot break a hop mid-write

## .rework

clean — the body is one string in `aws.reach.set.sh` section 4; B is a two-line swap.

## .confidence — 95%

- the one residual: infra could later give `[default]` a `credential_process`.
  B would then work, and A would still work; no change is owed either way

## .where

`.agent/repo=.this/role=any/skills/aws.reach.set.sh` section 4; vision `.the contract we propose`.

## .verdict

settled by measurement — A. the wish's B fails on the box it names.
