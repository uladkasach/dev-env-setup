# domain.term: unwipeable

term.chosen   = unwipeable
term.kind     = adj
term.synonyms.forbidden:
- pinned       (⛔ the sharpest one. `pin` already means the exact identity of a FETCHED artifact
                here — a version, a hash, a commit. to reuse it for "do not delete" would overload
                the word across two unrelated axes, in a repo that pins 7 bundles)
- protected    (implies a permission system decides. no permission is consulted — the exclusion is
                a fact about what the OWNER can rebuild)
- immortal     (implies it outlives the process. it dies with the process like any buffer; what it
                cannot survive is a WIPE)
- sacred       (carries a judgment about worth. this is not about value — a leaked buffer and the
                cached one are worth the same; one is replaceable and one is not)
- keep         (the variable name in the code, and too generic for a contract — it names the
                ACTION taken, where this names the PROPERTY that compels it)

## .what
of a resource: **its owner made it once, cached its handle, and will never rebuild it** — so a
wipe that deletes it breaks the owner for the life of the process.

the property is about the OWNER's behavior, never about the resource itself. two buffers can be
byte-identical, same filetype, same buftype, and one is unwipeable.

## .the test
> **if this is deleted, will its owner make another?**

- yes → wipeable. it is leak, or it is replaceable, and either way the wipe is safe
- **no** → unwipeable, and it belongs in the exclusion whatever else it matches

⚠️ the test asks about the OWNER, so it cannot be answered from the resource. no filetype, no
buftype, no modified flag distinguishes the two — which is exactly why the property needs a word
and a list rather than a smarter predicate.

## .the one member today
`neominimap.buffer.internal.empty_buffer` — created at module load, held as a bare integer,
never revalidated, never recreated (`buffer/internal.lua:25`).

⚠️ **one member is not a small list; it is an UNFINISHED one.** every plugin that caches a handle
has this property, and only the one that bit us has been read. an absent member looks identical
to a member that does not exist.

## .it names an axis two other words lost
`leaked` and `structural` were the candidates when this defect was diagnosed, and both were
deferred as unpaved (`progress.md`, 2026-09-06). the dop that landed chose neither, and the
reason is instructive: both name what a resource **is**, and the property is about what its owner
**does**. a word for the wrong half would have been paved and then drifted.

## .refs
- `src/grove.provision/4.terminal/4.5.nvim/init.lua` — `get_buffers_unwipeable`, the dop that declares it
- `term=wipe._.choice._.md` — the act this is the exclusion half of
- `term=pin._.choice._.md` — the word this must not be confused with

## .reason
see the ref-level cluster beside this choice:
- `term=unwipeable._.choice.reason.md` — etymology, the `pinned` dispute, and the measured gap
  that the word is still untested by any clamp
