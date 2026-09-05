# domain.term: dox

term.chosen   = dox
term.kind     = noun
term.synonyms.forbidden:
- secret (taken, and a DIFFERENT category — see the table below; to merge them prescribes
  the wrong response for one of the two)
- pii (narrower — it covers a person, and most of what this repo leaks names a MACHINE)
- sensitive-info / sensitive-data (says an item was judged sensitive, not what it enables)
- leak (names the EVENT, not the item — a leak is how dox got out)
- identifier (too broad — a slug and a bundle name are identifiers and are meant to be read)

## .what
an identifier in a public artifact that lets a stranger **point a tool at a real resource or
a real person**. an account id, an arn, a role name, an instance id, a private host, a bucket,
a secret's PATH, a person's city or username.

dox is **not confidential**. it is a target primitive: it converts a broad scan into a narrow
one. that is precisely why it needs its own word — the instinct is to wave it off because
"an account id is not a secret", and that instinct is correct about confidentiality and wrong
about risk.

## .the split from `secret`, which is the whole reason the word exists

| | dox | secret |
|---|---|---|
| what it is | names a real resource | GRANTS access to one |
| example | `arn:aws:iam::<acct>:role/<role>` | a token, a private key, an api key |
| the fix | **redact** — placeholder it | **rotate** — a redaction does not settle it |
| history rewrite | usually not worth it | secondary to the rotation, but consider it |
| severity | blocker | blocker, **and the credential is already burned** |

⚠️ the two demand OPPOSITE first moves. to redact a secret is to feel safe while the
credential still works. to rotate an account id is impossible. one word for both would
prescribe the wrong first move half the time.

## .what is NOT dox
- a public org, repo, package, or vendor name — to name them is the point
- a **concept** with no identifier: "the camp account", "the grove role". the concept is fine;
  its identifier is not
- a conventional dummy: `123456789012`, `i-0123456789abcdef0`, `0.0.0.0`, `jane.doe@…`

## .refs
where the term is used:
- .agent/repo=.this/role=any/briefs/creds/rule.forbid.dox-in-public-repo.md   # the rule; booted say-level 2026-08-08
- .agent/repo=.this/role=any/boot.yml                                   # why it is say-level

## .reason
see the ref-level cluster beside this choice:
- `term=dox._.choice.reason.md` — the etymology, the measurement that settled the split
  from `secret`, and why a rule that was correct stopped none of it
