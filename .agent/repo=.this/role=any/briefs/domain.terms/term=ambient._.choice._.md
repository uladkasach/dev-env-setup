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

## .reason

see the ref-level file beside this choice:

- `term=ambient._.choice.reason.md` — etymology, the trace that forced the word, why each
  forbidden synonym is forbidden
