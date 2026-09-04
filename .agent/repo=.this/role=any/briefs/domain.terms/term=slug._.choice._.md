# domain.term: slug

term.chosen   = slug
term.kind     = noun
term.synonyms.forbidden:
- coordinate   (geometry jargon, and it implies a position that can be computed. a slug is
                DECLARED, never derived — see `.the three axes`)
- slot         (names an empty container, so it says the value is absent. a slug is the
                address whether or not a value sits at it)
- entry        (names a ROW in the rack — the storage half. the slug is what addresses that
                row, and the two are exactly the pair `term=declared` splits)
- key          (already the name of ONE of the slug's three axes. to reuse it for the whole
                is the overload that hid this round's defect — see `.reason`)
- path         (filesystem jargon; a slug names no file, and the rack's one file holds many)
- id / handle  (generic, and neither says the address is composed of parts)

## .what
the composed address of one credential on the rack: `<org>.<env>.<KEY>`.

```
ahbode.prep.EHMPATHY_SEATURTLE_GITHUB_TOKEN
└─org  └env └key
```

keyrack prints it in exactly that form, so the word is adopted from the tool and kept
verbatim (`rule.require.conform-to-sdk-environment`'s habit). `--owner` is NOT part of the
slug — it names which rack is opened, not which credential inside it.

## .the three axes, each of which can be wrong in silence
this is why the term is load-bear: a slug is not one string a human types, it is three
independent declarations that must all agree, and two of the three fail QUIETLY.

| axis | wrong how | what it looks like |
|---|---|---|
| `org` | a sigil axis — `@this` / `@all`. a literal is accepted only when it EQUALS the manifest org, so it is `@this` spelled out, never a selector | ✋ loud — `org 'whodis' does not match manifest org 'ahbode'` |
| `env` | a real env that declares no such key | 🫧 quiet — `status: absent` |
| `key` | undeclared in every `keyrack.yml` | 🫧 quiet — a `set` prints `✔ set`, every get says `absent` |

`@this` points at the **root** manifest's org, no matter which nested manifest declared the
key — so a key declared under `repo=ehmpathy` still lives at `ahbode.*`.

## .a slug is DECLARED before it is filled
the slug's `key` axis must appear in a `keyrack.yml` before any value can be read back at it.
that is the `declared` / `live` pair applied to a credential (`term=declared`), and it is what
makes two of the three axes fail quietly rather than loudly.

## .refs
- .agent/keyrack.yml                                          # the root manifest — its org is what `@this` means
- .agent/repo=ehmpathy/role=mechanic/keyrack.yml              # declares the key axis of this repo's github slug
- src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh    # names the slug in one place, reads and halts with the same one
- src/grove.provision/5.devtools/5.4.gh/configure.verify.sh
- .agent/repo=.this/role=any/skills/git.grove.auth.github.set.sh  # prints the slug, then sets it
- .agent/repo=.this/role=any/briefs/creds/grove.auth.github.roadmap.md

## .reason
see the ref-level cluster beside this choice:
- `term=slug._.choice.reason.md` — why `key` was declined despite being the word everyone
  reaches for, and the dated evidence that four synonyms for one concept let a defect live
  in two mechanisms at once
