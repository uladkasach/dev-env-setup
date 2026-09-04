# domain.term.choice.reason: slug

## .etymology

adopted verbatim from keyrack, which prints the composed address in exactly this form:

```
🔐 keyrack
   └─ ahbode.prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN
      ├─ status: absent 🫧
```

the word is borrowed rather than coined, on purpose. a reader who greps keyrack's output and a
reader who greps this repo's bundles should land on the same word, so this repo keeps the
tool's vocabulary wherever it has no better one (`rule.require.conform-to-sdk-environment`).

## ⚠️ .why `key` lost, though it is the word everyone reaches for

`key` already names the slug's THIRD AXIS. `--key EHMPATHY_SEATURTLE_GITHUB_TOKEN` is one part
of `ahbode.prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN`, so to also call the whole address a "key"
overloads one word across a part and its container.

that overload is not theoretical — it is precisely how 2026-08-02's defect stayed hidden. every
sentence about the credential said "the key", and "the key" was ambiguous between:

- the KEY axis — is `GITHUB_TOKEN` declared anywhere? (it was not)
- the whole SLUG — does `@all.prep.GITHUB_TOKEN` name a readable address? (it did not)

when one word covers both, a check of the first reads as a check of the second. `5.4.gh` and
`git.grove.auth.github.set` each asked "do we have the key?", each answered from the wrong half,
and both shipped.

`rule.forbid.domain-term-synonyms` names the synonym as the usual culprit. this is its twin —
the OVERLOAD — and the costlier of the two: a synonym merely costs a reader a translation,
while an overload lets a wrong answer wear a right one's face.

## .the evidence — four words for one concept, in one round

within a single session these all named one concept, in this repo's own contracts and prose:

| word | where |
|---|---|
| `slug` | keyrack's output; `git.grove.auth.github.set`'s `slug:` line |
| `coordinate` | `5.4.gh`'s comments — *"the one rack coordinate this repo's token lives at"* |
| `slot` | the halt text — *"step 1 declares WHERE the token is stored"*, and `keyrack fill`'s prose |
| `entry` | `grove.auth.github.roadmap.md` — *"`@all` says this entry belongs to no single org"* |

four words, one concept, no glossary line — the exact condition
`rule.require.domain-term-itemization` exists to end. the chosen word is the one the TOOL
already prints, so the repo and its dependency agree rather than diverge.

## .why this term is itemized at all, though it is imported vocabulary

`rule.require.domain-term-itemization` puts dependency vocabulary out of scope —
`DomainEntity` is domain-objects' term, not this repo's. `slug` sits on the line: keyrack
coined it, and this repo reuses it.

it earns a cluster anyway, for one reason: **the sprawl was ours.** keyrack says `slug`
consistently. files in this repo introduced `coordinate`, `slot`, and `entry`, in contracts a
human reads at the moment they can least afford to guess. the rule targets a concept this
domain speaks about in more than one voice, and this is one — whoever named it first.

so the cluster claims no authorship. it records that this repo ADOPTS keyrack's word and
forbids the three it invented alongside it.

## .the measurement that earned it

`prove.keyrack.roundtrip` on grove-1, 2026-08-02:

1. `keyrack set` of `@all.prep.GROVE_ROUNDTRIP_PROBE` → `✔ set`
2. `keyrack get` of that same slug → `status: absent 🫧`
3. cause: no `keyrack.yml` declares that key, so the KEY axis never existed
4. and separately: `--org ehmpathy` is refused outright — `does not match manifest org 'ahbode'`

step 1 and step 2 name the same string and disagree about it. that reads as a defect only once
the three axes have one name, and each axis has its own.

## .the second measurement — a slug's ORG axis is checked on READ and not on WRITE

grove-1, 2026-08-03. the same three axes; this time the defect sits on ONE of them.

| act | asked with | keyrack answered |
|---|---|---|
| set | `--org @all --env camp --key GITHUB_TOKEN` | `✔ set` · `keyrack list` shows it · a new `.age` lands on disk |
| get | `--org @all …` | `status: absent 🫧` — with `--unlock`, with `--allow-dangerous`, at env `camp` and `prep`, through vault `os.secure` and `os.direct` |
| get | the literal slug, `--key @all.camp.GITHUB_TOKEN` | `BadRequestError: slug org '@all' does not match manifest org 'ahbode'` |
| set | `--org @this …` | `ahbode.camp.GITHUB_TOKEN` · get returns it byte for byte, cold from a relocked daemon |

the third row names it: the READ path checks the slug's org against the manifest's org, and the
WRITE path does not. so `@all` composes a slug a caller can write and never read.

### ⚠️ that bug is FIXED — the measurement above is history, not present tense

rhachet@1.45.1, measured 2026-08-05 on the laptop, against a real `@all` entry:

| act | asked with | stdout |
|---|---|---|
| get | `--org @all --env prep --key BRAINS_AUTH__…__seaturtle --unlock --value` | **108 bytes** — a real value |
| get (control) | the same call, key `DEFINITELY_NOT_A_REAL_KEY_XYZ` | **0 bytes** · `absent 🫧` on stderr |

the control makes it proof rather than a hopeful read: an absent key writes its tree to
**stderr** and leaves stdout empty, so a non-zero stdout byte count can only be a value.

and row 3's literal-slug rejection is gone. keyrack takes a literal org now — but **only when
it equals the manifest org**, so it is `@this` spelled out, never a free selector:

```
get --org ahbode …   ✔ composed ahbode.prep.… , reached the pat firewall
get --org whodis …   ✋ ConstraintError: org 'whodis' does not match manifest org 'ahbode'
```

⚠️ **and row 2's 2026-08-03 `absent 🫧` was probably never keyrack's fault.** that probe wrote a
fake classic-pat-shaped value and never confirmed it landed — so either the pat firewall
refused the store, or the value went in empty. a broken probe read as a broken tool, and the
wrong conclusion then landed in THIS file as evidence.

> the term survives all of that: `slug` still names the address, and the lesson below is still
> the durable one. what changed is that a paragraph of *evidence* in a glossary file was false
> for two days. evidence decays faster than the term it justifies — date it, and re-read it
> before you cite it (`rule.require.trust-but-verify`).

⚠️ the lesson for this glossary is narrower and more durable than the bug: **a slug is an
address, and an address guarantees no reachability.** `✔ set` reports that a record landed; it
says no word about whether the slug that names it resolves again. two sessions read `✔ set` as
"the credential is placed" and were wrong both times, at the cost of a real pat each.

⚠️ note also that `all` is itself overloaded across two axes: `--env all` is an ENV value,
`--org @all` is an ORG sigil, and they differ. `keyrack unlock --env all` widens the env axis
and leaves the org axis at the manifest's, so it enumerates `ahbode.*` only. one word, two
axes — the same overload this file already forbids for `key`, one axis over.

## 🛑 .the third measurement — the ORG SIGIL decides which REPAIR is legal

the two measurements above cover how keyrack checks a slug. this one covers what a slug's org
axis tells an AUTHOR. measured on a from-scratch grove, 2026-08-25.

two call sites read a credential the same way — a `$( … 2>/dev/null )` whose empty result
reports as *"the rack holds none"*. one took a repair with `env -C "$gitroot"`, a fixed root
that removes the cwd from the read entirely (`5.4.gh/configure.upsert.sh:206`). the obvious
move copies it to the other four.

**that would be a regression**, and one axis of the slug is the reason:

| site | slug | what the org axis means | `env -C "$gitroot"` |
|---|---|---|---|
| `5.4.gh` | `@all.camp.GITHUB_TOKEN` | `@all` — machine-wide, and `setKeyrackKeyHost` excludes it from every repo manifest | ✔ the cwd is genuinely noise |
| `git.grove.wake` +4 | `@this.<env>.AWS_PROFILE` | `@this` — the ROOT manifest's org, which is what picks the aws account | ✋ answers for one org from inside another |

`aws.reach.set.sh:32` had already stated the second row, in the repo, before anyone asked:

> a keyrack slug is natively `<org>.<env>.<KEY>`, so org+env is already the axis the rack
> indexes on … a repo in a different org gets its own **by virtue of its org**

⇒ so the sigil is not merely another way to write the org. **it declares whether the cwd is an
INPUT to the address or noise on the way to it.** no repair that touches the cwd is safe to
copy across sites that differ in it.

### .the general form

> a fix that neutralizes the cwd is legal for `@all` and forbidden for `@this`.

read the sigil before the repair, never after. the two sites look identical at the shell —
same skill, same flags, same swallow — and the sigil is the only token that separates a
strict improvement from a credential answered against the wrong account.

📜 a human refused this reach on 2026-08-25: *"they're of course dependent since we depend on
the gitrepo's org's creds to specify which aws account"*. the proposal classed the cwd as
`ambient` where the sigil declares it `declared` — `term=ambient._.choice._.md` forbids
`implicit` as a synonym for exactly this reason.

## .disputes

### dispute: entry  —  raised 2026-08-02  —  status: RESOLVED (both terms stand, for different concepts)

this file predicted `entry` as the likeliest future dispute, and named the condition to settle
it: *"if the rack ever needs a term for 'the stored record as distinct from its address'"*.
2026-08-03 met that condition — a record existed (`keyrack list` showed it, the `.age` file sat
on disk) while its address stayed unresolvable. record and address came apart, so they are two
concepts and need two words.

- claim      = `entry` and `slug` name one thing, so one should be forbidden
- counter    = a record can exist while its address will not resolve; the round above is the
               measurement. one word for both makes "the entry is there" and "the slug
               resolves" read as one sentence — precisely the failure that spent two pats
- resolution = `slug` = the ADDRESS. `entry` = the STORED RECORD it points at. `entry` stays
               forbidden as a word for the address; it is now itemized in its own right
               (`term=entry._.choice._.md`)

`entry` is no longer a future dispute — part of its case was already on the page.

`grove.auth.github.roadmap.md` uses `entry` four times, and in each the concept is the STORED
RECORD rather than its address:

```
:169  one entry, scoped per request
:211  how the box learns the entry exists
:223  why `--scope` and not one entry per org
:225  the credential entry is one, and the request narrows it
```

those stand, deliberately. none violates `rule.forbid.domain-term-synonyms`, because none means
*slug* — each means the row the slug points at.

so the forbid on `entry` is narrow: forbidden **as a word for the address**, canonical for the
stored record. that record now has its own cluster (`term=entry._.choice._.md`), and the four
lines above are where it started.
