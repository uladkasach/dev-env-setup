# domain.term: ambient

term.chosen   = ambient
term.kind     = adj
term.synonyms.forbidden:
- instance
- default
- imds
- inherited
- implicit

## .what

of an identity or capability: **already present on the box, by virtue of what the box IS**
rather than by any act this repo performed. a cloud grove is ec2, so its iam instance role
is ambient — it needs no fetch, no store, and no rotation from us.

it names a PROVENANCE, not a mechanism. the ambient identity on aws arrives via IMDS; on
another host it might arrive another way, and the word would still fit.

## .refs

the `[profile ambient]` block, and the phases that declare and prove it:

- `src/grove.provision/5.devtools/5.6.aws/configure.upsert.sh` — writes the profile
- `src/grove.provision/5.devtools/5.6.aws/configure.verify.sh` — proves it yields credentials

## .the pair it completes

`ambient` sits opposite `rack` on the where-does-a-credential-come-from axis:

| | `rack` | `ambient` |
|---|---|---|
| provenance | placed by a human, held in a vault | present because of what the box is |
| rotation | ours to do | the platform's |
| absence | a fillable gap | a fact about the machine |
| example | `@all.camp.GITHUB_TOKEN` | `<camp-grove-role>` |

a credential is one or the other, never both, and the two must be treated in opposite ways
— which is why one word for each earns its place.

## 🛑 .the WORD is a provenance; the rack VALUE spelled `ambient` is NARROWER

a rack `AWS_PROFILE` holds a profile NAME, and exactly one name is the string `ambient`.
so two different claims wear one word:

| the claim | true of |
|---|---|
| this credential is AMBIENT | every profile whose body sets `credential_source = Ec2InstanceMetadata` — the badge, and every role it assumes from |
| this rack value IS `ambient` | only where the badge answers with NO HOP |

a hopped profile — `<org>.<env>.<owner>`, which assumes an env-account role FROM the badge
— is ambient in provenance and is not spelled `ambient`. it stores no secret and rotates
on the platform's clock, exactly as the badge does
(`5.13.reach/configure.upsert.sh`: *"every profile this writes sets
`credential_source = Ec2InstanceMetadata`"*).

⇒ the table above parts credentials by PROVENANCE. it is silent on how many hops sit
between the badge and the account a call lands in.

⇒ so **to read a value that is not `ambient` as a credential that is not ambient is a
misread**, and it fires on every hopped profile. the value answers *how many hops*; the
word answers *where it came from*.

## .reason

see the ref-level file beside this choice:

- `term=ambient._.choice.reason.md` — etymology, the trace that forced the word, why each
  forbidden synonym is forbidden
