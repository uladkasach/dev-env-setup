# domain.term: exid

term.chosen   = exid
term.kind     = noun
term.synonyms.forbidden:
- name         (taken, and it is the OTHER half of this pair — a grove's name is local and
                free; its exid is the address infra assigns. to conflate them is the defect
                this term exists to prevent)
- id           (generic, and it reads as the instance id `i-…`, which is a THIRD identifier
                the exid is not)
- tag          (names the aws MECHANISM that carries the exid, not the exid itself. an exid
                happens to be stored as a Name tag; that is where it lives, not what it is)
- alias        (taken by `grove.alias` — the ssh Host a duct rides. an alias addresses a
                CONNECTION, an exid addresses a BOX)
- slug         (taken, and at a different subject — a slug addresses a credential on the rack)
- handle / ref (generic; neither says the identifier is external, nor who owns it)

## .what
the **external** identifier of a box — the value infra assigns and this repo looks a machine
up BY. `ex` = external: it is authored elsewhere, and we only ever read it.

```
rhx git.grove.set <name> --exid <the-box-infra-named>
                  └local, ours   └external, infra's
```

## ⚠️ .the pair that matters — name is OURS, exid is THEIRS

| | name | exid |
|---|---|---|
| authored by | us | **infra** |
| scope | this registry | the aws account |
| changes when | we rename it | **infra replaces the box** |
| survives a rebuild | yes — it is a local json record | **no** |

a grove's registry entry holds both. `git.grove.wake` resolves the box **by exid**, so the
name is a habit and the exid is the address.

⇒ **when infra rebuilds, the habit survives and the address does not.** the entry keeps its
answer, and that answer describes a box that is gone.

## .why a term, and not merely a field

because the failure is silent. a stale exid does not error with "no such host" — it fails
at the aws lookup, or finds some *other* instance that still carries the tag. the entry
looks healthy throughout.

this is the same shape as `term=slug`'s three axes and `term=entry`'s store-vs-read: an
identifier DECLARED locally and RESOLVED remotely can be well-formed and still address no
live thing. the word exists so a reader asks *whose* identifier this is before they trust it.

## .the free check
```sh
rhx git.grove.get <name>     # read exid; compare against what infra handed you
```

## .refs
- src/bash_aliases.sh                                  # `--exid` on `git grove set`; the registry field
- .agent/repo=.this/role=any/skills/git.grove.wake.sh  # resolves a box BY exid
- .agent/repo=.this/role=any/skills/git.grove.stop.sh
- .agent/repo=.this/role=any/skills/aws.ec2.get.sh
- .agent/repo=.this/role=any/briefs/grove/reach/howto.adopt-a-replacement-grove.md

## .reason
see the ref-level cluster beside this choice:
- `term=exid._.choice.reason.md` — the etymology, the `name` dispute, and the 2026-08-10
  near-miss that settled it
