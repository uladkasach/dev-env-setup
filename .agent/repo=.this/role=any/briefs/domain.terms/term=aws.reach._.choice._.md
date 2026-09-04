# domain.term: aws.reach

term.chosen   = aws.reach
term.kind     = noun (and verb — `a box reaches an account`)
term.synonyms.forbidden:
- access
- assume
- auth
- permission
- grant
- credential

## .what
a box's ability to ACT in one org+env's aws account — the whole chain from the badge
it holds, through the profile that names the hop, to a call that answers there.

it is the CHAIN, not any one link. a box with valid credentials and no profile has no
reach; so does a box with a profile whose role refuses it.

## .refs
- `.agent/repo=.this/role=any/skills/aws.reach.set.sh`         # the operation
- `src/grove.provision/5.devtools/5.13.reach/`                  # the bundle
- `.agent/repo=.this/role=any/briefs/creds/howdoes.a-box-reach-an-aws-account.md`
- `.agent/repo=.this/role=any/briefs/creds/handoff.infra.grove-account-reach.md`

## .why the `aws.` prefix
this dir requires a term to carry its bounded context (`.readme.md` — `grove.stop`,
never a bare `stop`), and a bare `reach` would claim the whole repo. it cannot: two
extant rules already reach OTHER things —
`rule.require.reach-a-grove-through-its-duct` and
`rule.require.reach-credentials-through-keyrack`. three contexts, one verb.

⚠️ those two are NOT synonyms of this term and are not forbidden by it. they are
different acts on different objects, and each would earn its own prefixed cluster
(`grove.reach`, `keyrack.reach`) the day one is itemized. the prefix is what keeps the
glossary from LOOKING settled while it is ambiguous.

### ✔ the prediction landed — 2026-09-03, and from a fourth context

`brains.auth` arrived from main with a cluster filed as a **bare `reach`**, and it named
a different concept again: the email address an oauth token reports as its own identity.

| term | what it names | kind |
|---|---|---|
| `aws.reach` | a box's ABILITY to act in an account | a capability chain |
| `brains.auth.reach` | an ADDRESS a token reports as its own | an identifier |

it was prefixed to `brains.auth.reach` on arrival, on this block's own argument. ⇒ the
paragraph above is not a hypothetical: **four contexts now reach**, and the one that
walked in bare walked in from another branch, where no `aws.reach` sat beside it to make
the clash visible.

⚠️ read that as the general hazard, not a fact about one port: **a term is unambiguous in
the tree it was authored in and is only tested against the tree it LANDS in.** so a pull,
a merge, or a cherry-pick is exactly when a bare term earns a second look.

## .reason
see the ref-level cluster beside this choice:
- `term=aws.reach._.choice.reason.md` — etymology, the rejected synonyms, evidence
