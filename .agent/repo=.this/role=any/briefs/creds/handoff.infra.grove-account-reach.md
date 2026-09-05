# handoff.infra.grove-account-reach

> **to:** whoever owns `ahbode/infrastructure`
> **from:** dev-env-setup, grove-1
> **date:** 2026-08-08
> **status:** ✅ **no ask that blocks us.** the grant we needed already exists
> and is proven. one optional hardener is named at the bottom.

## .the short version

grove-1 can already assume into the prep account. we measured it, twice, from
the box. what was broken was on **our** side: the grove had no `[profile …]`
that expressed the hop, so every call went out as the camp role and was
correctly refused.

**you owe us no change to ship this.** read on only for the record, or for the
optional hardener at the end.

## .what we thought was broken

svc-chat's integration suite on grove-1 died 22 of 31 tests with:

```
User: arn:aws:sts::<camp-acct>:assumed-role/<camp-grove-role>/<instance-id>
is not authorized to perform: SNS:Publish
on resource: arn:aws:sns:us-east-1:<prep-acct>:svc-chat-test-…
```

read fast, that says "the camp role has no reach into prep." it does not. it
says the camp role acted **directly** on a prep resource and was refused — which
is correct behavior, and says no word about whether it may **assume** into that
account. it never tried.

## .what is actually true — measured on grove-1

```
$ aws sts get-caller-identity                       # the box's own badge
arn:aws:sts::<camp-acct>:assumed-role/<camp-grove-role>/<instance-id>

$ aws sts assume-role \
    --role-arn arn:aws:iam::<prep-acct>:role/<prep-oidc-role> \
    --role-session-name grove-reach-probe
✔ arn:aws:sts::<prep-acct>:assumed-role/<prep-oidc-role>/grove-reach-probe
```

the hop is **live**. `AllowGroveCampAssumeRole` in `resources.reach.ts` already
names `<camp-grove-role>` as a principal on the prep OIDC role, and it is
applied.

⚠️ we nearly filed the opposite report. an earlier probe guessed three role
names — `ahbode-test-role`, `ahbode-prep-role`,
`OrganizationAccountAccessRole` — collected three `AccessDenied`s, and read them
as "the grove has no prep access." **a role name that does not exist refuses
with the same message as a role that excludes you.** the real name, read from
`resources.role-names.ts` rather than recalled, assumed on the first try.

## .what we fixed on our side

a new skill, `rhx aws.reach.set`, writes the profile that expresses the hop, and
proves it with a live sts call before it reports success:

```ini
# on the grove — ~/.aws/config
[profile ahbode.test.ehmpath]
role_arn          = arn:aws:iam::<prep-acct>:role/<prep-oidc-role>
credential_source = Ec2InstanceMetadata
region            = us-east-1
```

✔ proven on grove-1, 2026-08-08, plan → apply → apply:

```
whoami: arn:aws:sts::<prep-acct>:assumed-role/<prep-oidc-role>/botocore-session-…
```

this matches the design your team described back, exactly:

| host | how `ahbode.prep.ehmpath` gets credentials |
|---|---|
| laptop | `sso_session` → interactive sso login → prep |
| grove | `role_arn` + `credential_source = Ec2InstanceMetadata` → chains off the grove badge |

the profile **name** is identical on both, so the command a human types is
identical on both. that is the whole contract, and it is unchanged.

## .the one item worth a conversation (optional, blocks nobody)

today a grove reaches prep by assumption of `<prep-oidc-role>` — a role whose
primary job is github-actions OIDC, extended with a second trust statement for
the camp grove role. it works. two reasons to consider a split later:

1. **mixed trust is hard to reason about.** one role's trust policy now answers
   two unrelated questions ("which workflows?" and "which groves?"), so a change
   to either audience touches the other's blast radius.
2. **a grove and a workflow want different power.** a grove is a long-lived
   interactive box; a CI job is ephemeral and scoped. one permission set has to
   be the union.

if you want to split it, the shape we would consume is:

| from | to | account | role | power |
|---|---|---|---|---|
| `<camp-grove-role>` | prep | <prep-acct> | `<prep-for-grove-role>` | everyday-power |
| `<camp-grove-role>` | prod | <prod-acct> | `<prod-for-grove-role>` | everyday-reader |

- trusted **only** by `<camp-grove-role>` (no OIDC principal)
- names declared in `resources.role-names.ts`, so consumers read them rather
  than guess them
- `AllowGroveCampAssumeRole` then drops off the OIDC roles

**our cost to adopt is one flag.** the role name is an input to our skill, never
a guess:

```sh
rhx aws.reach.set --org ahbode --env test --role <prep-for-grove-role> --mode apply
```

so: ship it whenever it suits your roadmap. we are unblocked either way.

## .the one ask that IS a request, and it is small

when you add or rename a cross-account role, please keep the name in
`provision/aws.auth/resources.role-names.ts`. that file is the single place we
read from:

```sh
rhx git.repo.get lines --in ahbode/infrastructure --words 'ROLE_NAME'
```

a name that lives only in a terraform local, or only in a person's memory, is
the input that produced the false "no access" report above.

## .the account map we now hold, for confirmation

| env | account | note |
|---|---|---|
| root | <root-acct> | |
| **test** | **<prep-acct>** | the same account as prep, split by `infrastructureNamespaceId` (`7ade8a21`) rather than by an account boundary |
| prep | <prep-acct> | |
| prod | <prod-acct> | |
| camp | <camp-acct> | where groves live |

⚠️ please confirm that test and prep share one account on purpose, and that it
is stable. our skill reads these from each repo's `declapract.use.yml`
(`awsAccountId.dev` / `.prep` / `.prod`), so a drift between that declaration
and reality is a class of silent failure — a profile that assumes cleanly into
the wrong account.

## .see also (ours, if you want to read the mechanism)

- `.agent/repo=.this/role=any/briefs/creds/howdoes.a-box-reach-an-aws-account.md`
- `.agent/repo=.this/role=any/skills/aws.reach.set.sh`
