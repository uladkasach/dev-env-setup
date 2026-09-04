# domain.term: boundary

term.chosen   = boundary
term.kind     = noun
term.synonyms.forbidden:
- wrapper
- gateway
- facade
- chokepoint
- layer

## .what
the ONE declared operation through which every call of a KIND must route, so a guarantee that
kind needs is declared once rather than at each call site.

`src/grove.web.sh` is the **wire** boundary: every fetch, every hash check, every signature
check, every registry bound. `src/grove.pkg.sh` is the **package** boundary: `pkg_install`,
and the `PKG_APT_ENV` that keeps apt non-interactive.

## .the shape it always takes

| it holds | so a call site does not |
|---|---|
| the bound (`--within`, `-k`) | re-type a timeout, or omit one |
| the guarantee (`PKG_APT_ENV`) | re-declare it, or drift from it |
| the check (sha256, gpg, the pin) | decide per call whether to verify |

⇒ **a boundary is what makes `bare` a defect rather than a style.** without one, a call with
no wrapper is merely a call written differently; with one, it is a call that went AROUND the
single declaration (`term=bare`).

## 🛑 .a boundary is DECLARED ONCE, or it is not a boundary

two copies of one boundary is the m.9 shape — one set, two readers, free to drift with no
signal. so where a second declaration is unavoidable (`grove.bootstrap.sh` runs before the
repo exists, and cannot source `grove.pkg.sh`), the copy is CLAMPED by a play rather than
trusted (`rule.require.identical-bundle-composition`).

⚠️ and a boundary a caller cannot REACH is not one for that caller. a play sent by
`git.grove.send --play` lands as ONE file on the box, so a boundary it sources by a relative
path is absent there — the reach is part of the declaration, never an afterthought.

## .why it is bare, not `wire.boundary`
the word means exactly the same of the wire, the package manager, kitty's IPC, and infra's
lifecycle split, so it spans contexts rather than belongs to one — the same allowance
`declared` / `live` / `bare` take. the SUBJECT is named beside it ("the wire boundary", "the
package boundary"), which keeps one word and any number of subjects.

## .refs
where the term is declared / used:
- src/grove.web.sh                                       # "the wire boundary"
- src/grove.pkg.sh                                       # the package boundary
- .agent/repo=.this/role=any/skills/termwork.test.sh       # the IPC boundary
- .agent/repo=.this/role=any/skills/git.grove.infra.operations.sh
- .agent/repo=.this/role=any/skills/aws.reach.set.sh

## .reason
see the ref-level cluster beside this choice:
- `term=boundary._.choice.reason.md` — etymology, rejected synonyms, when a concern
  earns one, and why an unreachable boundary is no boundary
