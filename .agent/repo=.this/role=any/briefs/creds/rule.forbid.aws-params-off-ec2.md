# rule.forbid.aws-params-off-ec2

## .what

**a key is read from, or written to, `aws.params` on an ec2 box ONLY.**

a local grove and a house grove have no ec2 identity. there, every key lives in
`os.secure` (or a human's own login, as `gh auth login`), and **no command may write a key
into `aws.params`** — not a bundle, not a skill, not a fix-text.

| box | ec2 identity (IMDS) | vault for a key |
|---|---|---|
| cloud grove | ✔ — every cloud grove is ec2, for now | `aws.params` |
| local grove | ✋ never | `os.secure` |
| house grove | ✋ never | `os.secure` |

## .why

`aws.params` has one identity it trusts on its own: the instance role IMDS hands an ec2 box.
off ec2 there is none, so an `aws.params` read or write runs as **whatever aws credential
the shell happens to hold** — a human's sso profile, a stale export, or none. that yields
one of three failures, and all three break the box:

1. **the read fails** → the provision halts on a box that was healthy
2. **the write lands in the wrong account** → the value exists, and no read on any box finds
   it (`term=entry`, the fifth cause)
3. **the entry is rewired to `aws.params`** → a key that worked from `os.secure` goes dark,
   and the next suite dies on it

⚠️ the aws cli on the box proves none of this. a laptop HAS the cli; what it lacks is the
identity. so a gate on `command -v aws` lets every one of the three through.

## .the gate

judge the PLATFORM, never the word grove and never the tier:

```sh
[[ "$GROVE_ENV_SERVER" == *@aws.ec2 ]]    # 5.12.rack: grove_provision_5_12_rack_platform_is_ec2
```

- `aws.ec2` names the fact the vault depends on; `cloud` names only how the box is reached
- a tag this repo does not know yet — a house grove's — fails CLOSED
- a skill that acts on a REMOTE box asks that box instead: the IMDS token request
  `5.6.aws` makes, run over ssh (`git.grove.auth.github.set`, rung 0b)

## .where it is enforced

| site | off ec2 it… |
|---|---|
| `5.12.rack` upsert | declines the `@all.camp.GITHUB_TOKEN` read of ssm and its `aws.params` set |
| `5.12.rack` verify | declines the read that entry would answer |
| `5.16.keys` verify | names `os.secure` in its fix-text, and never `aws.params` |
| `git.grove.auth.github.set` | refuses at rung 0b, before any prompt |
| `git.grove.auth.keys.set` | already writes `os.secure` on the far side |

## .enforcement

- a write to `aws.params` reachable on a box that is not `*@aws.ec2` = **blocker**
- a fix-text that names `--vault aws.params` to a human on such a box = **blocker**
- a comment or brief that says a GROVE is always ec2, where it means a CLOUD grove =
  **blocker** — a grove spans local, house, and cloud (`repo.overview`), and that sentence is
  what let the unguarded write stand

## .see also

- `rule.require.github-token-at-all-camp` — why a cloud grove's github token IS `aws.params`
- `term=entry._.choice._.md` — the store-versus-read split, and the wrong-account cause
- `repo.overview` — a grove spans both kinds; a sentence true of one is a defect
