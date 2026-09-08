# domain.term: wipe

term.chosen   = wipe
term.kind     = verb
term.synonyms.forbidden:
- clear        (implies the contents are emptied and the container survives. a wipe DELETES the
                container, and that difference is the whole defect this word was paved after)
- purge        (implies a bulk sweep on a schedule. a wipe fires from one breaker trip, once)
- clean        (says the RESULT is tidy and says none of what was destroyed to get there)
- free         (names memory returned. a wipe may free zero and still have deleted state —
                measured `reclaimed_mb=-26` on a real trip, 2026-09-06)
- reap         (already the forbidden synonym of `breaker`, on the same axis — a reap runs on a
                clock, a wipe on a condition)

## .what
delete a set of resources a `breaker.trip` selected by predicate. the second of the trip's three
steps, and **the only one that destroys**.

```
   wiped=13 kept=1     ← a real trip line, 2026-09-06T16:43:47
```

## 🛑 .a wipe's predicate is a DELETE CONTRACT, and it needs TWO halves

this is the whole reason the verb earns a term rather than a comment:

| half | question it answers | how it goes wrong |
|---|---|---|
| the **match** | what MAY be deleted | too narrow → the leak survives |
| the **exclusion** | what must NEVER be, however well it matches | absent → unrebuildable state dies |

⚠️ a predicate written with only the first half **reads complete**. it names the machinery's own
artifacts and every one it matches is genuinely the machinery's. it is still wrong, because the
set a wipe MAY delete is not the set it is SAFE to delete (`term=unwipeable`).

## .a wipe reports what it did, in BOTH directions
`wiped=N kept=M`. the kept count is not decoration — it is the only evidence a reader has that
the exclusion fired at all. a wipe that reports its deletions and stays silent about its
exclusions cannot be told from one that has no exclusion (`rule.forbid.failhide`).

## .refs
- `src/grove.provision/4.terminal/4.5.nvim/init.lua` — the one wipe declared here, inside `trip_breaker`
- `term=breaker.trip._.choice._.md` — the act this is step 2 of
- `term=unwipeable._.choice._.md` — the exclusion half of the contract

## .reason
see the ref-level cluster beside this choice:
- `term=wipe._.choice.reason.md` — etymology, the `clear` dispute, the two-halves evidence
