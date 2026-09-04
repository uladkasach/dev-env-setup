# domain.term: duct.uri.scope

term.chosen   = scope
term.kind     = noun
term.synonyms.forbidden:
- pattern       # implies a glob engine; a scope has no wildcard semantics
- filter        # a filter tests each item; a scope NAMES a region of the address
- glob          # the `*` this replaced, retired 2026-07-29
- prefix        # true of the implementation, but it names the mechanism, not the concept

## .what
a duct uri read as **as much of the address as you know**. it names a region of the
address space rather than one duct.

```
duct://grove-1                the grove — every duct on it
duct://grove-1/main           one tree — every role in it
duct://grove-1/main/mechanic  one duct
duct:///                      this machine — every duct here
```

## .why it is not a second grammar
a scope IS a duct uri (`term=duct.uri._.choice._.md`), just one with the right-hand
segments left off — exactly how a directory path already names its contents. so `--on`
keeps one vocabulary, and an address widens or narrows by how much of it you write.

## .where it applies — reads only
| verb | reads `--on` as | why |
|------|-----------------|-----|
| `duct.list` | a **scope** | it reports; a wide address is a wide report |
| `duct.open` / `send` / `read` / `stop` | a **strict uri** | they ACT; a wide address would act widely |

`duct.stop --on duct://grove-1` is an ERROR, deliberately: under scope rules it would read
as "the whole grove", so one dropped segment would kill every duct on the box.

## .refs
- src/ductwork.sh                                  # `__duct_parse_uri_scope`, `DUCT_SCOPE`
- src/ductwork.sh                                  # `duct.list --on`
- .agent/repo=.this/role=any/skills/duct.list.sh   # the rhx surface

## .reason
see the ref-level cluster beside this choice:
- `term=duct.uri.scope._.choice.reason.md` — etymology, the retired `*`, evidence
