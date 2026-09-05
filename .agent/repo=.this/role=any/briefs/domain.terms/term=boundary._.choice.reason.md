# domain.term.choice.reason: boundary

## .etymology

`boundary` = the line a call must cross to leave one concern for another. the word is
already the shape: on this side, a caller with a job; on the far side, a resource with
rules — and exactly ONE place where the two meet, so the rules are stated once.

that is why it reads the same of the wire, of apt, of kitty's IPC, and of infra's
lifecycle split. each names a far side with rules; each has one declared crossing point.

## 🛑 .when a concern EARNS a boundary — three, all of them

a wrapper is not a boundary. the word is earned only where all three hold:

| # | test | if absent |
|---|---|---|
| 1 | **many call sites** | one caller needs no declaration beside itself |
| 2 | **a guarantee they must not re-decide** — a bound, a hash, a `PKG_APT_ENV` | a helper, not a boundary; call sites may vary freely and be correct |
| 3 | **the absence is SILENT** | a call that fails loudly teaches its own lesson; a bare one that answers wrong does not |

⇒ row 3 is the one most often skipped, and it is what separates a boundary from a lint
rule. `web_fetch` exists because an unverified download SUCCEEDS — it produces bytes, and
the bytes are wrong. `pkg_apt` exists because a bare apt call HANGS rather than errors.

## .the rack question, answered by the three tests — 2026-08-15

the open design fork is whether a keyrack read gets one. run the tests:

| # | the rack read |
|---|---|
| 1 | **24 call sites** across skills, playbooks, and bundles |
| 2 | the guarantee is a **cwd that resolves to a rack root** — the caller has no business to decide it |
| 3 | the failure is `2>/dev/null` into an empty string, **indistinguishable from "no credential"** |

3 of 3. so the concern earns a boundary by this term's own test, and the fork is about
WHERE it is declared, never about whether.

⚠️ **and the term is what shows the repair sits at the WRONG LAYER.** the resolver would
exist only because rhachet's cli demands a git root for an operation that needs none, and
loads the cwd's manifest before it reads an `@all` sigil that wants no manifest at all. a
boundary that wraps an upstream over-requirement is a workaround with a good name —
legitimate to build, and never the part to celebrate (`rule.require.solve-at-cause`).

⇒ so the honest order is: report the upstream defect, and declare the boundary meanwhile.
the boundary is then a **bridge with a known end date**, which is a different artifact from
one that encodes a permanent domain rule (`web_fetch`), and its comment must say so.

## .rejected synonyms

| word | why not |
|---|---|
| `wrapper` | already a term here, and it is the GENERAL word — every boundary is a wrapper, and almost no wrapper is a boundary. to spell them alike would erase the three tests above (`term=wrapper`) |
| `gateway` | it says a call passes THROUGH and says no word about the single declaration, which is the whole claim. two gateways over one resource is unremarkable; two boundaries is the m.9 defect |
| `facade` | it names a simpler face over a complex subsystem — a legibility claim. `pkg_apt` is not simpler than `apt-get`; it is SAFER, and safety is the point |
| `chokepoint` | true of the traffic and false of the intent. it reads as a constriction to route around, where a boundary is the road |
| `layer` | a layer is a horizontal band of a stack; a boundary is one operation. `grove.web.sh` is not a layer under the bundles — it is a door in the wall beside them |

## .evidence

five subjects, four authors, one word — and no author coordinated it:

```
src/grove.web.sh                     "the wire boundary" — declared in its own header
src/grove.pkg.sh                     pkg_install / pkg_apt / PKG_APT_ENV
skills/termwork.test.sh:298           the IPC boundary
skills/git.grove.infra.operations.sh  "so the boundary holds"
skills/aws.reach.set.sh               the credential boundary
```

and two clamps exist for no reason other than to keep a boundary a boundary:

- `prove.every-fetch-is-verified` — every fetch routes through the wire boundary
- `prove.registry-bounds-agree` — the two unavoidable copies of one bound stay identical

## .the invariants

> **a boundary is DECLARED ONCE.** two copies is one set with two readers, free to drift
> with no signal (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

> **an unavoidable copy is CLAMPED, never trusted.** `grove.bootstrap.sh` runs before the
> repo exists, so it cannot source the boundary — and a play holds it to the original
> (`rule.require.identical-bundle-composition`).

> **a boundary a caller cannot REACH is not one for that caller.** `--play` lands ONE file
> on a box, so a play that sources a lib is silently local-only. the reach belongs in the
> declaration, never as an afterthought.

⚠️ that third invariant was measured, not reasoned: several static plays source a shared
lib today and hold only because no one has sent them down a duct yet.

## .disputes

none raised.
