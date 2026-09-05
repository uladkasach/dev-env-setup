# domain.term.choice.reason: duct.uri

## .etymology

*uri* is the w3c term for a **uniform resource identifier** — a scheme, an authority, and a
path. it is adopted, not coined, and it earns its keep on the word **uniform**: the format
is one shape in every direction, which is the exact property this address lacked.

`url` was rejected as the near-neighbor. a url is a uri that **locates** over a network
protocol. `duct://` names a duct reached over ssh into tmux, which no url scheme registry
knows. every duct uri is a uri; not one is a url.

## .what it retires — the slug

before this round `--on` took an scp-shaped **slug**:

```
--on   grove-1:main/mechanic          <- what you typed
print  duct://grove-1/main/mechanic   <- what you read back
```

two forms of one address. a human read the second and had to reshape it by hand, from
memory, to use the first. that is **recall where recognition belongs**, and it is
`rule.require.ubiqlang` failed on this repo's own contract.

## .the human's question, which was the whole argument

> can we just make the uri the only format? no slug, only uri?
>
> why would we need a slug shape?

the honest answer, once checked, was **we would not**. the search found no constraint:
one parser, four entry points, and a registry keyed on the SESSION rather than the
address. no store held a slug.

## .why the slug looked inevitable, and was not

`host:path` is the scp/rsync convention, so the shape felt native. but `--on` is not scp —
it addresses a **duct**, an object this repo declares (`term=duct`). a declared domain
object owes a transport no syntax. the slug was ssh's grammar, worn by a concept that had
outgrown it.

this is a general trap worth the record: **a convention borrowed from the mechanism reads
as inevitable long after the concept has outgrown it.** the same shape as `term=duct` vs
`session`, one level down.

## .the claim that blocked it, and was wrong

the render helper carried this note, written one hour before the rename:

> never parse this back — a round-trip would be ambiguous anyway: with no host, the first
> path segment is a tree, not an authority.

that is only true if the empty authority is **collapsed**. keep it and no ambiguity is
left at all:

| uri | authority | session |
|-----|-----------|---------|
| `duct://grove-1/main/mechanic` | `grove-1` | `main/mechanic` |
| `duct:///worktree/mechanic` | *(empty)* | `worktree/mechanic` |

`file:///` solved this in 1994. **the triple slash is what makes one format sufficient** —
and the robot had written the impossibility claim without a test behind it.

## .the payoff was deletion

`__duct_uri`, the render helper authored one hour earlier — with a careful comment on how
its expansions must MIRROR the parser exactly, lest a display show one duct while it
addressed another — became dead code the moment input and display were one format.

that comment was real diligence spent to guard a seam that should not have existed. **a
careful guard on an unnecessary seam is a signal to delete the seam.** net −40 lines, one
parser, one format, and the whole class of mirror-drift defects gone with it.

## .why the bare form failsloud rather than aliases

to accept `worktree/mechanic` as "obviously local" would restore the second format under
another name, and the failure mode is worse than untidy: a mistyped `grove-1/duct://x`
parses as a LOCAL duct named `grove-1` — a send to the wrong machine that reports success.
so an address without a scheme is refused, with both shapes named
(`rule.require.errors-name-the-fix`).

the parse call sites gained `|| return 2` for the same reason. without it the parser
printed its error and the verb carried on with an empty host and session — a failhide
(`rule.forbid.failhide`).

## .evidence

verified live, all four paths, after a real install:

```
remote    🔧 duct://grove-1/main/mechanic sent            → echo round-tripped
local     🔧 duct:///urltest/mechanic created (local)     → sent + read + stopped
old slug  ✋ duct: --on takes a duct URI, got 'grove-1:main/mechanic'
no duct   ✋ duct: 'duct://grove-1' names a host but no duct
```

- decomposition: an address has exactly two axes — WHICH MACHINE (authority) and WHICH
  DUCT ON IT (path). the uri walks that product with no leftover cell, and the empty
  authority is the local cell rather than a special case
- the narrative test: a traveler says "read duct://grove-1/main/mechanic" and the words
  are the address, spoken aloud — the bar `def.domain-discovery` sets

## .a lesson about the tool, not the term

the first verification PASSED against the old format — because the Bash tool's shell held
a snapshot of the pre-edit functions. the robot caught it only because the *display* was
pre-edit too. a fresh `source` then showed the correct refusal.

**a test that runs against a stale definition proves little, and looks like proof.** when a
shell-sourced contract changes, re-source before you verify.

## .disputes

none open.
