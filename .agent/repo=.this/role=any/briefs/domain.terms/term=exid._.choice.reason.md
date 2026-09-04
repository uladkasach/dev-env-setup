# domain.term.choice.reason: exid

## .etymology

`exid` = **ex**ternal **id**. the word was already in the code — `git grove set --exid`, the
registry field, and the lookups in `git.grove.wake` / `git.grove.stop` / `aws.ec2.get` — so
this cluster adopts a term the repo declares rather than coins one
(`rule.require.conform-to-sdk-environment`'s habit, applied inward).

the `ex` prefix is the whole value of the word. `id` alone would say an identifier exists;
`exid` says **somebody else authored it**. that single fact is what decides whether the value
can go stale underneath you, and it is the fact a reader needs first.

## .why it earned a cluster on 2026-08-10

`exid` had been in use for as long as the grove family has existed, unitemized, and it read
as a plain field. then it produced a near-miss.

infra replaced the box: `grove-ahbode-v20260810` / `<instance-id>`, up and healthy.
the mechanic's first move was:

```sh
rhx git.grove.wake grove-1
```

— because `grove-1` is the name every prior session used. a human stopped it: *"its clearly
NOT grove-1"*. the registry then showed why:

```json
{ "name": "grove-1", "exid": "grove-1", "account": "…", "status": "active" }
```

`status: active`, and the box it names is gone. the next command in the queue was a
`grove.provision` — a convergence run, against whatever that stale exid happened to find.

## .the discovery — a local record of a remote fact cannot tell it went stale

the registry is a json file on the caller's disk. it is never a live read. so:

- **the name is ours** — local, free, and it survives anything
- **the exid is theirs** — it addresses a box in infra's account, and it dies with that box

a single entry holds both, which is what makes them so easy to conflate. every prior session
typed `grove-1` and meant *the box we work on*; the word had been correct for months, and it
became wrong with no local change at all.

> a grove NAME is a habit. a grove EXID is an address. when infra rebuilds, the habit
> survives and the address does not.

⚠️ the failure mode is **quiet**, which is why the term is load-bear rather than decorative.
`wake` resolves by exid TAG, so a dead exid does not announce itself as a bad hostname — it
fails deep in an aws lookup, or matches some *other* instance that still carries the tag. no
part of the entry ever reads as unhealthy.

## .the family it belongs to

this repo now holds three terms for "an identifier declared in one place and resolved in
another", and each was itemized after the same kind of silent miss:

| term | addresses | declared | resolved | how it fails |
|---|---|---|---|---|
| `slug` | a credential | a `keyrack.yml` | the rack | 2 of 3 axes go quiet |
| `entry` | a stored record | a `set` | a `get` | `✔ set` proves the store, not the read |
| `exid` | a box | our registry | infra's account | a live-looking entry names a dead box |

that these three keep recurring is itself the finding: **the repo's most expensive defects
are not wrong values, they are correct-looking addresses.**

## .disputes

### dispute: name — raised 2026-08-10 — status: RESOLVED (keep both, they are a PAIR)
- raised.by  = mechanic
- claim      = the registry already has `name`, and `name` is what a human types and reads.
               a second identifier is redundant ceremony; collapse to one and the near-miss
               above cannot happen, because there is only one value left to go stale
- counter    = it is the opposite — the collapse CAUSES the miss. the two identifiers have
               different owners and different lifetimes, and the whole defect was that they
               were treated as one word. one identifier would mean either the name changes
               under us whenever infra rebuilds (and every alias, brief, and shell history
               breaks), or the address silently rots (which is what happened). the pair is
               load-bear: `name` gives a human a stable word, `exid` gives the machine a
               truthful address, and the registry's job is to hold the mapping between them
- resolution = keep both. `name` is forbidden as a synonym of `exid` and vice versa. the
               distinction is stated at say-level so it is always in context. dispute closed.

## .evidence

- **discovery** — the 2026-08-10 near-miss above, caught by a human, one command before a
  convergence run against an unidentified box
- **it is declared here** — 13 occurrences in `src/bash_aliases.sh`, 40 across 4 skills
  (`git.grove.wake`, `git.grove.stop`, `git.grove.trust.gen`, `aws.ec2.get`). ⚠️ this check
  was run BEFORE the cluster was written, because the round prior itemized a term for an
  operation that did not exist (`gotcha.my-own-note-became-my-evidence`)
- **the rule it serves** — `rule.require.trust-but-verify`. a registry entry is an inherited
  claim that wears the shape of a fact

## .see also
- `term=slug._.choice._.md` — the same address/thing split, for a credential
- `term=entry._.choice._.md` — the store half of a store-vs-read pair
- `term=grove.alias._.choice._.md` — addresses a CONNECTION, where an exid addresses a BOX
- `howto.adopt-a-replacement-grove.md` — the procedure this term makes legible
