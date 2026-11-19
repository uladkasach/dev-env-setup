# rule.require.aws-params-on-camp-groves-only

## .what

**every camp grove carries the camp aws identity, on every seat. `aws.params` is read or
written on a camp grove ONLY.**

the camp IS the aws account. a camp grove is the `cloud` tier (`cloud@*`); the platform names
HOW the identity arrives, never WHETHER:

| box | identity | vault |
|---|---|---|
| `cloud@aws.ec2` | instance role, via IMDS | `aws.params` |
| `cloud@hetzner.hetzbot` | infra's IAM Roles Anywhere signer, named by `[default]`'s endpoint | `aws.params` |
| `cloud@*` as `ground`, the admin seat | ✋ none, by design | — no credentialed work |
| `local@*`, `house@*` | ✋ none | `os.secure` |

⇒ the identity is a **mandated prereq of a camp seat** (`grove_env_seat_is_camp`): infra
provisions it, this repo asserts it, and a camp seat without it fails loud with infra named as
the owner. the admin seat converges box-wide facts only; every credentialed bundle declines
there (`grove_env_seat_is_admin`, `prove.admin-seat-holds-no-credentials`).

## .why the gate is the TIER

keyrack reads an `@all` slug as `source: imds`: it clears `AWS_PROFILE` and rides the sdk
default chain, so `[default]` answers — IMDS on ec2, the signer on hetzner.

📜 2026-11-15: a hetzner grove read and decrypted the fleet's `@all.camp.GITHUB_TOKEN`. the
prior rule gated on `*@aws.ec2` and declined every such read there. **a platform is a road; the
camp account is the destination.**

## .why off camp is forbidden

with no camp identity, a read or write runs as whatever credential the shell holds:

1. the read fails → a healthy provision halts
2. the write lands in the wrong account → no box reads it back (`term=entry`)
3. the entry is rewired to `aws.params` → an `os.secure` key that served goes dark

## .where it is enforced

| site | on camp | off camp |
|---|---|---|
| `5.6.aws` | ✋ if the seat's identity road is absent | 🌙 declines |
| `5.12.rack` (`_is_camp_grove`) | reads + sets the github token in `aws.params` | declines |
| `5.4.gh`, `5.16.keys` fix-texts | may name `aws.params` | name `os.secure` only |
| `git.grove.auth.github.set` rung 0b | passes once the far box's tier and identity answer | refuses before any prompt |

clamps: `prove.hetzner-default-profile-survives`, `prove.gh-names-aws-params-on-camp-groves-only`,
`prove.github-auth-set-refuses-off-camp`.

## .enforcement

- an `aws.params` write reachable off `cloud@*`, or a fix-text that names it there = **blocker**
- a gate on the PLATFORM where the need is the camp IDENTITY = **blocker**
- a camp seat with no identity reported as a 🌙 rather than a ✋ = **blocker**
- "a grove has the camp identity" where it means a CAMP grove = **blocker** (`repo.overview`)

## .see also

- `rule.require.github-token-at-all-camp` — why a camp grove's github token IS `aws.params`
- `term=entry._.choice._.md` — store versus read, and the wrong-account cause
