# F005 — which on-disk fact the hetzner probe reads

- **fork:** `/etc/ssh/sshd_config.d/00-grove.conf` + the `ground`/`camper` pair · a declared `/etc/grove` identity file the bootstrap writes · dmi (rejected by #172: an EX44 names the board maker)
- **taken, why:** the sshd drop-in, as #172 names it and the bootstrap already leaves it — no change to ahbode/infrastructure owed
- **rework:** dirty — a platform rung is read by every bundle; a wrong fact misclassifies a box tree-wide, and a switch to `/etc/grove` needs an infra change
- **risk:** low, by the director's bar (risky = a credential or a prod write; this touches neither, and a probe test case catches it). the failure modes stand: a fact that also matches a laptop flips the commander's box to `cloud` (his member join skipped, every `!= local@unix` gate wrong on it); a fact that misses a hetzner box leaves it `local@unix`, where F011 refuses the member join
- **confidence 55%, why low:** unmeasured on the hetzner box (no reach until the laptop joins); unknown whether an ec2 bootstrap writes the same drop-in, which would make it a non-discriminator
- **where:** vision `.the contract` §1, assumptions

## .verdict — 5.1.execution, 2026-10-26

the fact is a declared file: `/etc/grove/platform`, first line `hetzner.hetzbot` (`grove_env_probe_hetzner_hetzbot` in `src/grove.env.sh`). a declaration beats a heuristic over dmi or cloud-init, since a heuristic can name a box wrong in silence. the rung sits after the ec2 free rungs and before desktop. on this laptop the file is absent, so the ladder is unchanged here. the file is written by the hetzner bootstrap, which is `ahbode/infrastructure`'s (a handoff). until it lands, a hetzner box is refused by name, never mis-tagged, and `GROVE_ENV_SERVER=cloud@hetzner.hetzbot` is the named override.