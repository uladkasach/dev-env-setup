# domain.term.choice.reason: wipe

## .etymology

to **wipe** a disk, a tape, a record: the artifact is gone, not emptied. that finality is the
property the word must carry, because the alternative words all soften it — and a softened word
on a destructive act is how the act shipped unreviewed.

the noun form (`a wipe`) and the past participle (`wiped`, the log field) are the same word
applied to the act and its count. ordinary english, not second terms.

## .disputes

### dispute: clear  —  raised 2026-09-06  —  status: RESOLVED (keep `wipe`)

- claim      = `clear` is the gentler, more common word and reads fine: "clear the leaked
               minimap buffers". nvim's own api says `nvim_buf_clear_namespace`, so the
               vocabulary is already there.
- counter    = that api is exactly the counter-example. `nvim_buf_clear_namespace` EMPTIES a
               buffer's marks and the buffer survives; `nvim_buf_delete` destroys it. the two
               are different acts on the same subject, and this repo calls the second. to name
               it `clear` would borrow the word nvim already spends on the reversible one.
               the cost is not theoretical: the reader who approves a `clear` is approving
               something recoverable, and this act is not.
- resolution = keep `wipe`; record `clear`, `purge`, `clean`, `free`, `reap` as forbidden
               synonyms. `clear` stays legal for a call that genuinely empties without deletion.
               dispute closed.

## .evidence

### the two halves, measured 2026-09-06

the wipe was authored with a match half and no exclusion half, and shipped that way. its
predicate — filetype is `neominimap`, buffer unmodified — is **correct about every buffer it
matches**. every one of them is genuinely a minimap buffer, genuinely unmodified, genuinely the
plugin's own artifact.

it was still wrong, and the arms say so:

| arm | predicate | result |
|---|---|---|
| control | no wipe | `refresh_ok=true` |
| old | match half only | `wiped=1` → `Invalid buffer id: 2` |
| fixed | match + exclusion | `wiped=0 kept=1`, `refresh_ok=true` |

⇒ **a predicate can be true of every member it selects and still select a member that must not
be deleted.** correctness of the match says none of the safety of the delete. that sentence is
why the verb needed its own term instead of a comment on the loop.

### the report earns its keep — `kept=` was added the same round

the trip line reported `wiped=N` and no second number. so a run with a broken exclusion and a
run with no exclusion at all print the same evidence, and the first is invisible.

`kept=M` was added for exactly that reason. it is small, and it is the difference between a log
that records an act and a log that records a **contract**.

### a wipe may free zero, and the log now says so

measured on this box, `2026-09-06T16:43:47`:

```
TRIP rss_mb=1200 reclaimed_mb=-26 wiped=13 …
```

thirteen buffers deleted, and rss went **up** 26MB. the pressure was native, so the wipe was
destruction with no reclaim to show for it. that is the case `free` would have named wrongly,
and the reason it sits in the forbidden list.
