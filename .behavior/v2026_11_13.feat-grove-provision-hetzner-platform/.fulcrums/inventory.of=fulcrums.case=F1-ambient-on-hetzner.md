# F1 — `ambient` on hetzner mirrors `[default]`'s endpoint

## .the fork

camp-env consumers name `ambient` (the rack's camp `AWS_PROFILE`, `5.13.reach`'s gate, `aws.reach.set --env camp`). on hetzner the box's identity sits behind infra's `[default]`.

- **A — mirror.** `5.6.aws` writes a fenced `[profile ambient]` with ec2's body (`credential_source = Ec2InstanceMetadata`, `region`) plus `ec2_metadata_service_endpoint` read from `[default]` at apply time — the same one-line delta every hop carries (F5). every `ambient` reader stays as is
- **B — rename per platform.** no `ambient` on hetzner; the identity profile name is a function of the platform (`ambient` on ec2, `default` on hetzner), and each reader asks it

## .taken

A. it keeps one name for one concept across platforms (`rule.forbid.domain-term-synonyms`) and edits one writer, not three readers. the endpoint is read from infra's file, never typed, so no second home for the port.

## .rework

clean — the mirror lives in one fence in one bundle; B would swap it for a lookup in three readers, no data migration.

## .confidence — 65%, why low

- unmeasured: whether a profile with only `ec2_metadata_service_endpoint` falls through to the IMDS provider at that endpoint (Q2). if not, A fails and B (or a `credential_process` shape) is forced
- a mirror is a second copy of infra's endpoint; a moved port goes stale until the next apply

## .where

`src/grove.provision/5.devtools/5.6.aws/configure.upsert.sh`; vision `.the contract we propose`.

## .verdict

open — measure Q2 on the hetzner box before execution.
