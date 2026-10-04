# demo: 5.10.repos — the org axis, and the two namespaces its map spans

## .what

`5.10.repos` clones every repo of the orgs a grove's own org declares. two measurements
shaped that table: why it is per-org, and why it is a MAP rather than an identity.

## m1 — a flat clone set gave an AETHER grove three orgs' private repos and no aether repo

- 📜 2026-09-24: the set was the scalar `"ehmpathy ahbode whodisio"`, declared **twice** —
  the upsert's own default and the verify's inline copy — with no org axis at all
- ⇒ an aether grove cloned ahbode's, ehmpathy's, and whodisio's entire private repo sets,
  and cloned **no aether repo at all**
- the same defect `5.13.reach`, `5.12.rack`, and `5.16.keys` each carried, at a wider blast
  radius: **a reach row buys ONE account; a clone set buys every repo a token can see**
- ⇒ `rule.require.a-grove-reaches-its-own-org-only`. own-org is the default; every other
  row is an enumerated opt-in, stated beside its reason
- 🛑 an org with no arm clones NO REPO AT ALL. it does not fall back to another org's set —
  clause 3, and the clause a "sensible default" deletes

### the opt-ins on record, and why each is one

| key org | targets | why |
|---|---|---|
| `ahbode` | `ahbode ehmpathy whodisio` | ehmpathy is the generic infra org its services build on; whodisio is the identity org they authenticate through |
| `aether` | `aether-auctions` | own-org only. an aether box that wants ehmpathy's clones earns that row by AETHER's own opt-in, never by inheritance of ahbode's |

## m2 — the keyrack org and the github org are TWO namespaces, and they disagree today

the table's KEY is `GROVE_ORG` — the org the keyrack resolves against. its VALUES are
GITHUB orgs. these are different namespaces entirely.

- 📜 measured 2026-09-24: `aether` is the keyrack org and **`aether-auctions` is the github
  org**. an arm written as `aether) printf 'aether'` listed an org github does not have, so
  `gh repo list` answered with an empty set
- the bundle then reported `the token can see no repos here` — **a true verdict, about an
  org nobody owns**
- ⇒ never assume the two agree. read `gh repo list <org>` before an arm is declared
  (`rule.require.trust-but-verify`)

⚠️ `GROVE_GIT_ORGS` still overrides, for a human who wants one org's view. it is an
OVERRIDE and never a declaration — it reaches no other box.

## .see also

- `5.10.repos/_.sh` — the table these measurements back
- `gotcha.5-10-repos-two-readers.demo=clone-cut-partway` — the neighbor demo, on the
  three-state read and the two readers that share it
- `rule.require.a-grove-reaches-its-own-org-only` — the rule m1 bought
- `gotcha.5-13-reach.demo=per-org-rows-and-the-reap` — the same flat-scalar defect, one
  blast radius down
