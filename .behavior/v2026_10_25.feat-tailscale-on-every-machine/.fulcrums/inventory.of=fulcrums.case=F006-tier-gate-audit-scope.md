# F006 — the tier-gate audit lands inside this wish

- **fork:** audit every `local@unix` / `!= local@unix` / `cloud@*` / `*@aws.ec2` gate now · add the probe and leave the audit to #172
- **taken, why:** the moment hetzner reads `cloud`, each gate changes its answer there; a probe shipped without the audit could push an aws-only step (imds, ssm) onto hetzner — `rule.forbid.aws-params-off-ec2` keys on `*@aws.ec2`, so that one fails closed, the rest are unread
- **rework:** dirty — the audit can touch many bundles
- **status:** best-guessed. the blueprint may rework it, and scopes it out to its own wish if it grows
- **risk:** low, by the director's bar (risky = a credential or a prod write; this touches neither, and a test case catches a mis-sort). the failure modes stand: the audit rekeys live gates across bundles; a mis-sort can drop imds or ssm from an ec2 grove, or push a screen step onto a grove
- **confidence 60%, why low:** the commander chose "pull #172's probe in", not "and its step 4"; the audit's size is unknown until the blueprint counts the gates
- **where:** vision `.evaluation` cons, assumptions

## .verdict — 5.1.execution, 2026-10-26

did not grow; stays in this wish. the audit: every tier gate in the tree keys on `local@unix` versus not, or on `cloud@*`, so `cloud@hetzner.hetzbot` takes the cloud arm everywhere it should. the two aws-only steps (`5.6.aws`, `5.12.rack`) ask IMDS or `*@aws.ec2` directly, so they decline on hetzner (`rule.forbid.aws-params-off-ec2`). the two comments that said every cloud grove is ec2 were corrected at `5.6.aws/configure.upsert.sh` and `5.12.rack/_.sh`.