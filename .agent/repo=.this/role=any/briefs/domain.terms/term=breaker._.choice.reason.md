# domain.term.choice.reason: breaker

## .etymology

an electrical **circuit breaker** cuts a circuit when current passes a rated threshold, so the
cable survives the fault. three properties of that image carry, and each is load-bear:

1. **it protects the HOUSE, not the appliance.** the breaker's job is that the process lives —
   the machinery it cuts is expendable, and the human loses a minimap rather than an editor.
2. **it latches.** a tripped breaker stays tripped until somebody resets it. that is why
   `tripped` is set before the first cut: a breaker that re-arms itself is a throttle.
3. **its threshold is a guess.** 1.2GB was chosen to sit under systemd's `MemoryHigh=1.5G`, so
   the breaker fires before the cgroup does. that number is a judgment about headroom, never a
   measurement of correct use.

the repo word is the short form. `circuit breaker` the distributed-systems pattern is a
DIFFERENT concept — it cuts calls to a failed dependency — and is not a synonym here, because
this one's subject is the process's own resource use, never a peer.

## .disputes

### dispute: watchdog  —  raised 2026-09-06  —  status: RESOLVED (both survive — distinct concepts)

- claim      = the live code already calls itself a "self-watchdog", the notification says
               `nvim self-watchdog tripped`, and the log is `selfwatch.log`. one word would
               serve, and it is the word already on disk.
- counter    = they are the two halves of one mechanism, and the split is what the round needed.
               a **watchdog** OBSERVES — a 30s timer, a census, a trend line appended above a
               warn threshold. it is read-only, it runs every tick, and it is safe. a
               **breaker** CUTS — it runs once, it disables machinery, and it deletes state.
               to merge them buries a destructive act inside a word that reads as surveillance,
               which is precisely how the wipe of the cached buffer went unreviewed: it was
               added under "the watchdog" and it is not a watchdog act at all.
- resolution = both stand. `selfwatch` names the observer half and keeps its own word;
               `breaker` names the half that acts. `watchdog` is recorded as a forbidden
               synonym OF `breaker` — it stays legal for the observer. dispute closed.

⚠️ **this REFINES the axis the 2026-08-11 round drew, and does not overturn it.** that round
coined `scribe` and split it from the watchdog on *"a watchdog intervenes, a scribe only
records."* true at the time — the breaker had no name, so the timer and the trip were one word.
with the breaker named, the file holds three concepts on one axis:

| | acts on the process |
|---|---|
| `scribe` | never — records faults |
| `selfwatch` | never — records the memory trend |
| `breaker` | **yes** — disables, and deletes |

⇒ so the 2026-08-11 sentence should now read *"a **breaker** intervenes"*. left as written in
that round's `progress.md`, which is a dated record; the live axis is this table.

## .evidence

### the leaked/structural split, measured 2026-09-06

the round settled the term by payment of its cost. the defect: nvim threw
`Invalid buffer id: 2` from `neominimap/window/split/internal.lua:300` on every file open, for
the life of any session whose breaker had tripped.

the probe carried two arms plus the control the sixth probe hazard demands
(`term=probe._.choice._.md`):

| arm | wanted | got |
|---|---|---|
| control — no wipe | refresh holds | `valid_after=true`, `refresh_ok=true` |
| break — the live predicate | refresh throws | `valid_after=false`, `Invalid buffer id: 2` |

⚠️ the control arm is what earns the break arm. a break arm alone proves the buffer was invalid;
it says none of whether the config was already broken. the pair names the wipe as the cause.

⇒ the general lesson the word now carries: **a breaker's predicate is a delete contract, and a
delete contract needs an exclusion list.** the predicate was written to name what may be
reclaimed and was read as if it named what is safe to reclaim. those are different sets, and
their difference is one buffer that cannot be rebuilt.

### why the distinction has no term of its own — yet

`leaked` vs `structural` is the axis that carries the whole defect, and it is deliberately NOT
itemized. no dobj or dop in this repo declares either word today, so a cluster for them would be
a term minted to explain a fix that has not landed — the smell `grove.provision.slice` was
retracted for. when the exclusion lands and declares a name for what it keeps, that name earns
its cluster.

### the observer half is the older word, and it was NOT renamed

`selfwatch.log` is on disk, cited from `howto.review-nvim-errors`, and read by a human. the
dispute above split the concept without a rename, because the log names the observer and the
observer keeps its word. **a term dispute that resolves to two concepts should cost zero
renames** — if it demands one, check whether the split is real.
