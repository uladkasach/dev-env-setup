# domain.term.choice.reason: aws.reach

## .etymology

`reach` names the whole span between a box and an account — the way an arm reaches a
shelf. what makes it the right word here is that the span has SEVERAL links and the
domain's failures come from exactly one link at a time:

```
the badge        the box's own instance role (camp)
  ↓ assume       a role in the target account
the profile      [profile <org>.<env>.<owner>] in ~/.aws/config
  ↑ named by
the rack         <org>.<env>.AWS_PROFILE
```

a word for any single link would name a part and be read as the whole. `reach` is the
only candidate that is honestly about the span, so a claim made with it ("this box
reaches test") is falsifiable by one live call — which is what `aws.reach.set` does
before it reports ✔.

## .why each forbidden synonym is forbidden

| word | what it actually names | why it misleads here |
|---|---|---|
| `access` | a permission on a resource | it is the IAM word, so it reads as "an iam policy allows it" — and every failure in this domain so far was a policy that ALREADY allowed it and a box that never asked. `AccessDenied` is the error `reach` exists to keep a reader from misjudgment |
| `assume` | ONE link — the sts hop | true and partial. a box can assume perfectly and still have no reach, because no profile names the hop and no consumer knows to use it. that is exactly the state measured on 2026-08-08 |
| `auth` | proof of WHO you are | the box's identity was never in doubt in any incident here. the question is always what it may act as, WHERE |
| `permission` / `grant` | the other side's declaration | it is infra's word for their half. a box may hold every grant and still have no reach — `handoff.infra.grove-account-reach.md` is a whole document about that gap |
| `credential` | the secret itself | reach needs no stored credential at all on a grove: the badge is ambient and the hop is chained. to call it a credential invites somebody to store one |

## .evidence

### the two halves, and why one word must cover both

`aws.reach.set`'s header states the invariant this term exists to keep whole:

> a rack entry with no profile body names a profile aws cannot find; a profile body with
> no rack entry is a profile nobody names.

two halves, one word. a vocabulary that named them separately would let a run report
success with one of them written — which is what happened on 2026-08-10, when the
profile body landed and the rack half died on `Not inside a Git repository`.

### the failure this term is shaped to prevent

measured on grove-1 2026-08-08 and again on grove-ahbode-v20260810 2026-08-10:

```
User: arn:aws:sts::<camp-acct>:assumed-role/<camp-grove-role>/<instance>
is not authorized to perform: lambda:InvokeFunction
on resource: …:function:svc-service-providers-dev-findOrCreateProvider
```

read fast, that says the camp role has no ACCESS to dev. it does not. it says the camp
role acted **directly** on a dev resource and was refused — correct behavior — and says
no word about whether it may ASSUME into that account. it never tried.

`handoff.infra.grove-account-reach.md` records a session that nearly filed "the grove
has no prep access" on exactly that basis. the grove had it.

⇒ so the term must name the SPAN, because every incident in this domain is a reader who
mistook one link for the whole.

### it is measured, never asserted

a `reach` claim is always backed by a live `sts get-caller-identity` through the profile
in question, and the ACCOUNT in the answer is compared against the tree's declaration.
`5.13.reach/configure.verify.sh` does both, and the reason it checks the account rather
than mere success is that a profile aimed at the wrong account assumes CLEANLY and
answers happily.

## .disputes

none yet. the word was in use as a skill name (`aws.reach.set`) before it was itemized;
this cluster records the choice rather than makes it.
