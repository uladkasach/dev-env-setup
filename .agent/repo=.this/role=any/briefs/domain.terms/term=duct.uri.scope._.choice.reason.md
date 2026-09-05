# domain.term.choice.reason: duct.uri.scope

## .etymology

`scope` was not coined here. `rhx git.repo.test --scope` already takes one — a narrowed
region of the test space (`path://…`, `name://…`). the human types it weekly.

that makes this **reuse, not a new word**, and the reuse is honest: both narrow *which of a
declared space* an operation touches. one concept, one word, across two commands —
`rule.require.ubiqlang` satisfied rather than merely dodged.

## .what settled it — the human, 2026-07-29

the term arrived by way of the human's question about the syntax:

> why do we even need the /\* suffix? isnt --on duct://grove-1 enough?

and, on the shape of the match:

> yeah list can awlays just be prefix match

## .the choice this closed — the `*` suffix

`duct.list` had briefly demanded a star at the end: `duct.list --on 'duct://grove-1/*'`.

the star was authored under a plausible argument — "a machine is a duct URI with the
session part left open, and `*` says so outright". but it earned its keep nowhere:

1. **it disambiguated no second sense.** there was never another duct set
   `duct://grove-1` could have named. the star told the reader what they already knew.
2. **it cost quotes.** an unquoted `duct://grove-1/*` is globbed by the shell against the
   human's cwd before the verb ever sees it. so the syntax demanded a second rule —
   quote it — to defend against a token that bought no clarity.
3. **it implied a glob engine we never had.** the only two uses were "a grove" and "a
   tree", both plain prefixes. the star advertised wildcard semantics that had no
   implementation and needed none.

drop it and all three costs go with it. `duct://grove-1` is the whole address.

> **a token that disambiguates no second sense is not syntax; it is ceremony.**

## .why a prefix, and not a glob

the human said it in six words: *list can always just be prefix match*. that is the whole
requirement — the two real uses (a grove, a tree) are both prefixes, so a prefix needs no
wildcard semantics to explain and cannot grow a corner case.

one refinement the implementation adds: the match is **segment-aware**. a bare text prefix
would let the scope `main` match a duct named `mainline/x`, since that text does start with
`main`. an address names whole segments, so only a `/` may follow.

## .the split that keeps it safe

leniency in a READ verb must never leak into an ACTING verb. two parsers, deliberately:

| parser | used by | `duct://grove-1` |
|--------|---------|------------------|
| `__duct_parse_uri` (strict) | open, send, read, stop | **ERROR** — names a host but no duct |
| `__duct_parse_uri_scope` | list | the grove |

one shared parser would have been tidier and would have made `duct.stop --on duct://grove-1`
mean *stop the whole grove* — a typo that drops one segment becomes a mass kill that
reports success. the duplication is the guardrail (`rule.require.safe-by-default`).

## .evidence

- **precedent**: `rhx git.repo.test --scope 'path://src/domain.operations/customer'` — a
  narrowed region of a declared space, the same concept one level over
- **decomposition**: the duct address has exactly three segments (host / tree / role). a
  scope is that address truncated at any one of them, which walks the product with no
  leftover cell — 4 scopes for 3 segments (`///`, host, host+tree, host+tree+role)
- **the human's own words**: "isnt `--on duct://grove-1` enough?" — the shorter form was
  what they reached for unprompted, which is the `def.domain-discovery` bar

## .disputes

none open. the `*` it replaced is recorded as a forbidden synonym (`glob`) rather than
disputed, since the human settled it outright.
