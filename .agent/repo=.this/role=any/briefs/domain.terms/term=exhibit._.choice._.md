# domain.term: exhibit

term.chosen   = exhibit
term.kind     = noun
term.synonyms.forbidden:
- one-off      (names how OFTEN it ran; an exhibit is defined by where its RESULT went)
- scratch      (says it was careless work — an exhibit is often careful, and that is the point)
- throwaway    (same, and it says the file was disposable when WRITTEN; it became so later)
- legacy       (says old; an exhibit can be spent the same hour it was authored)
- dead code    (says unreachable; an exhibit RUNS fine — that is exactly the hazard)
- artifact     (every file is an artifact)
- snapshot     (taken: a captured terminal/session state — `term=snapshot._.choice._.md`)

## .what
an artifact whose entire value was to **measure one argument once**, and whose result now
lives somewhere else — a brief, a bundle comment, a term cluster.

an exhibit is **spent the moment its result lands elsewhere** — not when it breaks, not when
it ages. it usually still runs perfectly. that is what makes it costly rather than merely
surplus: it reads as coverage.

## .the test
an artifact is an exhibit when all three hold:
- its whole job was to answer ONE question, and that question is now settled
- the answer lives in a durable home somebody actually reads
- every reference to it reads as a **footnote** (*"the measurement that settled it"*) rather
  than a **reach** (*"run this first when a box says `absent 🫧`"*)

the third condition is the decidable one, and it is a grep. a citation is a footnote or a
reach; read the line that names it and the artifact classifies itself.

## .the peer set — what an artifact is INSTEAD of an exhibit
| kind | what it is | lifespan |
|---|---|---|
| tool | reached for WHEN a fault appears | as long as the fault can recur |
| clamp | re-proves a claim on every box, forever | as long as the claim holds |
| **exhibit** | measured one argument, once | **spent when the result lands** |

⚠️ `clamp` is **inherited vocabulary**, owned by `rule.require.clamp-edge-cases` (mechanic).
it is cited here, never re-itemized (`rule.require.domain-term-itemization` — imported vocab
is out of scope).

⚠️ `tool` IS this repo's own, and is itemized at `term=tool._.choice._.md` (2026-08-31). the
row above is its **lifespan** facet; that cluster carries the other half — its boundary against
`gate`, which is *who invokes it*. the two agree by construction, since *"reached for when a
fault appears"* names a human as the caller.
⇒ change one and change the other. this row and that cluster are one fact with two holders
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9), and they sat unlinked for three weeks.

## 🛑 .a SCRATCH play can be none of the three — it is uncommitted by construction
a scratch play lives in the gitignored `.play/temporary/`, so it is never committed and can
never rot into an exhibit (`term=play`). ⇒ this term governs **committed** artifacts: a skill,
a brief, a bundle phase, a fixture — and the one tracked play kind below.

⚠️ **a clamp MAY be a play, and one kind must be.** a discrimination probe breaks a subject on
purpose and confirms the check reddens; no read of a healthy box produces that evidence, so it
cannot live in a verify. it is tracked in `.play/permanent/` under `rule.forbid.repair-plays`
exception 2, and the dir is what makes it reach every box.

⇒ the test is the DIR, never the file suffix. `.play/temporary/` is uncommitted, so an artifact
there is outside this term. `.play/permanent/` is tracked, so an artifact there is a clamp and
this term's `exhibit` failure mode applies to it in full — a spent probe kept there is an
exhibit with a clamp's costume.

## ⚠️ .an exhibit is a second home for one fact
that is why it goes, and the cost is `term=drift`'s: two homes for one fact, no reader able to
tell which is current. between a brief and the exhibit that fed it, the **exhibit** is the one
that rots quietest — it re-runs against a machine that has moved on, while the brief stays true.

⇒ so the deletion is not tidiness. it is the same repair as a declaration drift: **remove one
home** (`rule.require.bundle-as-sole-declaration`).

## 🛑 .a delete is TWO edits
the file goes, AND every line that named it says what became of it. a bare removal turns a
good cull into a broken map — measured 2026-08-11, see the `.reason`.

## .refs
- .agent/repo=.this/role=any/briefs/grove/provision/howto.detect-env-server.md   # a footnote rewritten after a cull
- .agent/repo=.this/role=any/briefs/domain.terms/term=probe._.choice._.md   # the same, in a refs list
- .agent/repo=.this/role=any/briefs/shell/rule.require.wrap-cli-in-skills.md      # "an unnameable guard has already failed"
- .agent/repo=.this/role=any/briefs/domain.terms/term=drift._.choice._.md   # the cost of a second home

## .reason
see the ref-level cluster beside this choice:
- `term=exhibit._.choice.reason.md` — the museum etymology, the `one-off` dispute the human's
  own word opened, and the 2026-08-11 cull that measured all of it
