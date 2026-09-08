# domain.term.choice.reason: signature

## .etymology

a **signature** is the mark that identifies an author across every document they sign. it is
recognizable by eye, it repeats, and it is *meant* to be the same each time — which is precisely
the sense wanted here. the defect is the author; each error message is a document it signed.

the everyday sense also carries the human-readability that `hash` denies: a signature is what you
**recognize**, not what you look up.

## .evidence — the storm that forced it

the concept arrived from the human's first report:

> `Error in coroutine: ...neominimap/map/fold.lua:11: Invalid buffer id: 15968`

that buffer id is fresh on every occurrence. a raw-text log of a stale-handle storm therefore
yields thousands of distinct lines, each seen exactly once — a rank sorted by frequency would show
a flat sea of ones and name no defect at all. the rank only becomes legible once the digits that
vary are collapsed, so the collapse had to exist before the rank could carry any value.

the design followed from one question: **which two errors are the same defect?** the answer for
this class of fault is "identical but for the numbers", which is exactly what `%d+ → #` encodes.

## .the two-site hazard ⚠️

the collapse is implemented **twice**, and the pair must stay in agreement:

| site | why it derives the signature |
|------|------------------------------|
| `src/init.lua` → `as_signature()` | to dedup **at write time** (the repeat window, the tally) |
| `nvim.errors.review.sh` → the awk `sig` block | to group **at read time** (the rank) |

they are deliberately not shared — one is lua inside nvim, the other awk in a shell reader, with no
runtime between them. but if the two rules drift apart, the reader groups by a different
equivalence than the writer deduped by, and the counts silently disagree.

**a real instance of this already bit, and was caught when the skill was run on its own output.**
the exit tally first wrote the *collapsed* signature while live lines wrote the *raw* text. the two
forms then failed to group in the reader, so one fault ranked as two rows. the repair was to keep
the first-hit raw text on the entry and write that same text in the tally — the writer now emits
one byte-identical form, so the reader's collapse is the only one that matters.

**the lesson:** whenever the collapse rule changes on one side, it must change on the other, and
the check is a real rank — two rows where one belongs is the tell.

## .disputes

### dispute: fingerprint  —  raised 2026-08-11  —  status: RESOLVED (keep `signature`)
- raised.by  = mechanic
- claim      = "fingerprint" is the common word for a derived identity of a message, widely used
               in crash reporters and error aggregators for exactly this concept.
- counter    = a fingerprint's central property is that it is **unique per individual** — it tells
               two people apart. this derivation exists to do the opposite: to declare two
               distinct error instances **equal**. to adopt a word whose everyday sense is
               precisely inverted would mislead every reader who has not read the source.
- resolution = keep `signature`; record `fingerprint` as a forbidden synonym. dispute closed.

## .invariants

- a signature MUST be human-readable — it is printed as the rank's sample line, so any encode that
  obscures the original message (a digest, a checksum) is forbidden
- the write-side and read-side collapse rules MUST agree — a change to one demands a change to the
  other, verified against a real rank
- the raw message MUST be retained on the log line — the signature groups records, and never
  replaces them
