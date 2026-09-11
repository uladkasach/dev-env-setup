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
  - 🛑 **the dummy set is CLOSED, and `dox.verify.sh`'s exempt pattern is its ONE holder.** an
    author may not coin their own — an UNDECLARED dummy is indistinguishable from a real
    address to any reader, human or clamp, which is the whole reason one set is named
- 🛑 **an address at `example.com` is not dox, and it takes NO exempt entry** — RFC 2606 §3
  reserves the domain for documentation forever, so it can never route to a person. that is a
  declaration, and an external one: the property the exempt set has to assert per-string,
  `example.com` carries by standard
  - ⇒ so it is **outside the rule's subject**, never an exemption to it. the personal-email rule
    INCLUDES a list of consumer-mail and org domains (`dox.verify.sh`, `.why the email rule
    matches a DOMAIN LIST`), and a reserved domain is on neither — the exempt pattern stays the
    one holder of the exempt set, because this adds no member to it
  - ⇒ **a fixture that needs several distinct personas uses it**: `kai@example.com`,
    `moana@example.com`. the closed dummy set holds ONE address, so a suite that keys two rows
    on two identities cannot be written from it at all
  - ⚠️ 📜 so a persona this repo invented is **correctly flagged**, and the repair is to move
    the fixture onto the declared dummy — never to widen the set. measured 2026-09-07: a wider
    set was attempted HERE, in this list, and it contradicted a dream caught the same day
  - 🛑 **and the exemption was to be by PREFIX, which cannot work at all.** a walk of every hit
    the next day found a real personal address under one of the four prefixes the exemption
    named. ⇒ **inventedness is not a property of the string**, so no pattern can read it and
    only a declaration can carry it. `rule.forbid.exemption-as-habit` names the shape;
    `term=dox._.choice.reason.md` carries both measurements
- 📜 **the repo owner's own username**, where the owner has said so — settled 2026-09-07:
  *"vlad is fine"*. dox protects a person from a stranger; the person may waive it for
  themselves, in their own public repo, and `/home/vlad/` appears in every captured path
  here regardless
  - ⚠️ the waiver is on the USERNAME axis and does NOT extend to an **email address**. an
    address is a contact primitive — a spam and phish target a bare username is not — so it
    stays redacted until the owner says otherwise, per axis, never by inference

## .refs
where the term is used:
- .agent/repo=.this/role=any/briefs/creds/rule.forbid.dox-in-public-repo.md   # the rule; booted say-level 2026-08-08
- .agent/repo=.this/role=any/boot.yml                                   # why it is say-level

## .reason
see the ref-level cluster beside this choice:
- `term=dox._.choice.reason.md` — the etymology, the measurement that settled the split
  from `secret`, and why a rule that was correct stopped none of it
