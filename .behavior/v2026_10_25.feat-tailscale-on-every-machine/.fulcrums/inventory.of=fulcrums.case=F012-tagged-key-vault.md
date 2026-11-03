# F012 — the tagged key's vault

- **fork:** `aws.params` at `@all.camp` on ec2 + `os.secure` on hetzner · `os.secure` on every grove, placed by `git.grove.auth.keys.set` · a per-grove key in `aws.params`
- **taken, why:** ec2 follows `rule.require.github-token-at-all-camp` (one camp row, read by the instance role); hetzner has no ec2 identity, so `rule.forbid.aws-params-off-ec2` sends it to `os.secure`, placed by the extant `git.grove.auth.keys.set`
- **rework:** clean — one rack read in one upsert, plus a `5.16.keys` row
- **risk:** risky — a wrong vault reads `aws.params` off ec2, or finds no key, and the grove stays unjoined
- **confidence 70%, why low:** whether every camp grove's instance role reads `@all.camp` is infra's fact, unmeasured here; a reusable key at `@all.camp` vs a one-time key per grove is infra's call (#172 says one-time)
- **where:** vision `.the contract` §2, case 5, case 8

## .verdict — 5.1.execution, 2026-10-26

revised: one PER-ORG slug, `<org>.camp.TAILSCALE_AUTH_KEY`, on every grove, rather than `@all.camp` on ec2. a tagged key is minted for one org's tailnet, so `@all` would hand one org's key to another's grove (`rule.require.a-grove-reaches-its-own-org-only`). the vault still follows the platform: on ec2 the slug lives where that grove's rack reads `aws.params`; off ec2 it is `os.secure`, placed by `git.grove.auth.keys.set`, which the `ahbode:camp:TAILSCALE_AUTH_KEY` row in `5.16.keys` enables. `prove.org-scoped-rows` passes with the row.
## .ruled — the director, 2026-10-26

per-org `ahbode.camp.TAILSCALE_AUTH_KEY`, as built. it stands as a best-guessed fulcrum, and the rework to `@all.camp` is CLEAN: the slug lives in two functions in `5.23.tailscale/_.sh` (`_key_name`, `_key_env`), the `--org` of one read in `configure.upsert.sh`, and one row in `5.16.keys`. no box state keys on it until a key is filed.