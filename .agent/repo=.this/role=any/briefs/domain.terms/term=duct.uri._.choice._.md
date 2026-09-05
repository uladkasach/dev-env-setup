# domain.term: duct.uri

term.chosen   = duct.uri
term.kind     = noun
term.synonyms.forbidden:
- slug (the retired scp-shaped form, `grove-1:main/mechanic` — see `.reason`)
- address (generic; every identifier is an address)
- target (names a role in a call, not the duct itself)
- path (a duct is not a file; and the path is only ONE part of the uri)
- url (a uri that resolves over a network protocol; `duct://` resolves over ssh + tmux)

## .what
the one format that names a duct: `duct://<host>/<tree>/<role>`.

```
duct://grove-1/main/mechanic      remote — the host is the authority
duct:///worktree/mechanic         local  — an EMPTY authority means this machine
```

## .the rule it carries — one format, both directions
what `--on` accepts is exactly what every message prints. an address can be copied from
output back into input with no reshape. there is no second form.

## .its parts
| part | what | separator |
|------|------|-----------|
| `duct://` | the scheme | — |
| `<host>` | the reach: an ssh alias, or EMPTY for this machine | `//` … `/` |
| `<tree>/<role>` | the session, per ductwork's declared grammar | `/` |

## .the empty authority
`duct:///x` follows the `file:///` convention exactly — an empty authority means local.
that is what makes ONE format sufficient: the triple slash disambiguates, so a uri
round-trips with no second form.

## .what it refuses, and why loudly
a bare `worktree/mechanic` is an ERROR, not a local duct. to accept it "for convenience"
restores a second format under another name — and worse, a mistyped `grove-1/duct://x`
would silently address a LOCAL duct named `grove-1`: a send to the wrong machine that
reports success.

## .refs
where the term is declared / used:
- src/ductwork.sh                                  # `__duct_parse_uri`, every `--on`
- src/bash_aliases.sh                              # `_git_grove_duct_uri`
- .agent/repo=.this/role=any/briefs/desktop/term/howto.headless-terminal-streams.md

## .reason
see the ref-level cluster beside this choice:
- `term=duct.uri._.choice.reason.md` — etymology, the slug it retires, evidence
