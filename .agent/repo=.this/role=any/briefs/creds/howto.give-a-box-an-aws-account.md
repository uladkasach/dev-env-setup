# howto.give-a-box-an-aws-account

## .what

how to make one box — a laptop or a grove — able to act in one org's account, so
that `rhx git.repo.test --what integration` reaches the right aws and needs no
extra flag on either box.

one command per org+env:

```sh
rhx aws.reach.set --org ahbode --env test --role <prep-oidc-role> --mode apply
```

## .the shape you declare

a test suite never names an account. it reads `AWS_PROFILE` and trusts the box.
that pointer is **two halves**, and the whole trick is that only one of them
varies per box:

| half | what it is | where it lives | same on every box? |
|---|---|---|---|
| the **name** | `ahbode.test.ehmpath` | the keyrack, at `ahbode.test.AWS_PROFILE` | **yes** |
| the **body** | how that name gets credentials | `~/.aws/config` | **no** |

```
                       ahbode.test.AWS_PROFILE
                                 │
                    ┌────────────┴────────────┐
                    │   "ahbode.test.ehmpath" │   ← one name, both boxes
                    └────────────┬────────────┘
             ┌───────────────────┴───────────────────┐
     on a LAPTOP                                on a GROVE
     [profile ahbode.test.ehmpath]              [profile ahbode.test.ehmpath]
     sso_session    = ahbode.test.ehmpath       role_arn          = arn:…:role/<prep-oidc-role>
     sso_account_id = <prep-acct>              credential_source = Ec2InstanceMetadata
     sso_role_name  = everyday-power            region            = us-east-1
             │                                          │
       an sso login                          the grove's own badge, chained
```

⇒ this is what lets `rule.require.identical-commands-on-every-server` hold for
aws. the command a human types is byte-identical; the box supplies the reach.

## .the name is `<org>.<env>.<owner>`

`ahbode.test.ehmpath`, `ahbode.prep.ehmpath`, `ahbode.prod.ehmpath`,
`ahbode.camp.ehmpath`. the `<owner>` tail is load-bear: one account carries
several seats (`everyday-power`, `everyday-reader`, `emergency-admin`), and the
tail keeps two seats off one name. so `~/.aws/config` also holds
`ahbode.prep.admin`, `ahbode.prod.reader`, and `ahbode.test.daily`.

## .do it

### on a grove

```sh
# 1. plan — it prints the exact block, writes no byte
rhx aws.reach.set --org ahbode --env test --role <prep-oidc-role>

# 2. apply — writes both halves, then PROVES them with a live sts call
rhx aws.reach.set --org ahbode --env test --role <prep-oidc-role> --mode apply
```

```
🌊 cowabunga! 'ahbode' env=test is reachable from this box
   ├─ name:   ahbode.test.AWS_PROFILE  =  ahbode.test.ehmpath
   ├─ body:   [profile ahbode.test.ehmpath] in ~/.aws/config
   ├─ whoami: arn:aws:sts::<prep-acct>:assumed-role/<prep-oidc-role>/…
```

the `whoami` line is the point. a written profile is not a live one — the ✔ is
earned by an `sts get-caller-identity` through the profile it just wrote, so a
role that does not exist, a trust policy that omits this grove, or a mistyped
account each fail here rather than three hours later inside a test.

### on a laptop

the skill **confirms and declines to author**. a laptop's body is an sso login,
whose `sso_start_url` the skill has no truthful source for — so it will not
invent one:

```
   └─ ✋ a laptop, and 'ahbode.test.ehmpath' is NOT declared
  fix: aws configure sso --profile ahbode.test.ehmpath
```

if the profile already exists (it does, for every ahbode env on this laptop),
the skill reports ✔ and does no work.

## .where `--account` comes from

you should rarely type it. a declapract repo already declares its accounts:

```yaml
# ahbode/svc-chat/declapract.use.yml
variables:
  awsAccountId:
    dev:  <prep-acct>
    prep: <prep-acct>
    prod: <prod-acct>
```

so, from inside such a repo — or with `--from` pointed at one — the account is
read, not recalled:

```sh
cd ~/git/ahbode/svc-chat
rhx aws.reach.set --org ahbode --env test --role <prep-oidc-role> --mode apply
#    ├─ account: <prep-acct> (declared: declapract.use.yml → awsAccountId.dev)
```

⚠️ **declapract says `dev`; the rack says `test`.** they name the same account
(both `<prep-acct>`) under two vocabularies, so `--env test` reads declapract's
`dev` row. the skill states that map rather than infer it — a quiet fallthrough
to `prep` would be an answer correct in shape and drawn off the wrong row.

## .where `--role` comes from

**never from memory.** read it from the org's infra repo:

```sh
rhx git.repo.get lines --in ahbode/infrastructure --words 'ROLE_NAME'
```

the ones in use today:

| org | env | account | role |
|---|---|---|---|
| ahbode | test / prep | <prep-acct> | `<prep-oidc-role>` |
| ahbode | prod | <prod-acct> | `<prod-oidc-role>` |
| ahbode | camp | <camp-acct> | *(no role — camp is the grove's own account)* |

⚠️ **a guessed role name refuses in a way that reads exactly like an absent
grant.** measured 2026-08-06: three guessed names, three refusals, and a near
report of "the grove has no prep access" about a grove that had it. the real
name assumed on the first try.

## .`--env camp` takes no role

camp is the account the grove itself lives in, so its instance role **is** the
identity — there is no hop. a `role_arn` there asks the badge to assume into its
own account, which refuses in a way that reads like a config error.

## .prove it end to end

```sh
rhx git.grove.send grove-1 --play prove.aws-reach-set
rhx git.grove.play.await grove-1 --lines 90
```

that play runs plan → apply → apply (the second apply is the idempotency rung),
counts the profile blocks, and then asks the questions a **consumer** asks — the
name off the rack, then sts through it — rather than a re-read of the file the
skill just wrote.

✔ measured on grove-1, 2026-08-08: one profile after two applies, and
`arn:aws:sts::<prep-acct>:assumed-role/<prep-oidc-role>/…` from a box whose own
badge is `arn:aws:sts::<camp-acct>:assumed-role/<camp-grove-role>/…`.

and the payoff, on the same box, from the same command a laptop takes:

```
rhx git.repo.test --what integration
   └─ 19 suites, 31 passed, 0 failed ✔   (it read 0 of 19 two days earlier)
```

⚠️ **run `prove.grove-aws-identity-chain` first on any box you touch.** it asks
the one question this skill cannot: does a bare `aws` call with NO profile named
still find a region and the box's own badge? that `[default]` block is the
regression clamp, and without it the box loses its own identity the moment a
consumer drops `AWS_PROFILE`.

## .the one prerequisite the skill cannot supply

`AWS_PROFILE` must be **declared** for that env in the consumer repo's
`.agent/keyrack.yml`. an undeclared key stores and then reads `absent 🫧`
forever (`domain.terms/term=entry`):

```yaml
env.test:
  - AWS_PROFILE
```

svc-chat already declares it under both `env.test` and `env.prep`. this repo
declares it only under `env.camp`, which is why a `keyrack get --env test` from
*this* checkout says `key not found in manifest` — correctly.

## .see also

- `howdoes.a-box-reach-an-aws-account.md` — the mechanism, for whoever changes it
- `rule.require.identical-commands-on-every-server` — the rule this serves
- `src/grove.provision/5.devtools/5.6.aws/` — the bundle that owns `ambient`
- `domain.terms/term=rack`, `term=slug`, `term=entry` — the vocabulary
