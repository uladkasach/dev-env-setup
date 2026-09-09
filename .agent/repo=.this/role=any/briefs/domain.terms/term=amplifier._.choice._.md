# domain.term: amplifier

term.chosen   = amplifier
term.kind     = noun
term.synonyms.forbidden:
- feedback-loop
- spiral
- snowball
- vicious-cycle
- cascade

## .what

a mechanism whose **own output re-enters its own input**, so its cost grows without any new
demand from outside.

the test that identifies one is the absence of an external driver. a workload grows because a
human asked for more; an amplifier grows because it already grew. remove every user and it keeps
its climb.

three properties follow, and together they earn the word:

1. **superlinear** — each cycle's output is the next cycle's input, so the population multiplies
   rather than adds
2. **no external cause** — every instrument that hunts a *source* finds none, because the source
   is the mechanism itself
3. **worst exactly when worst** — an amplifier's rate rises with the load it creates, so it does
   the most harm at the moment the machine can least afford it

## ⚠️ .not a `runaway`

`runaway` is already a hunt section in `machine.usage.diagnose`, so the boundary must be sharp:

| | `runaway` | `amplifier` |
|---|---|---|
| what it names | **one process** that consumes without bound | a **mechanism** that feeds itself |
| visible to `ps`? | yes — it tops the list | no — cost spreads across a class |
| the fix | kill the process | break the loop; a kill only resets the clock |

a runaway is a member. an amplifier is a relation. a kill of every member of an amplified class
restores the machine for an hour and changes no cause, which is precisely the trap the word
exists to name.

## .refs

**the instances:**

- `src/init.lua` — `neominimap` made minimaps of its own minimaps once `exclude_buftypes` was
  emptied. measured 2026-09-03: 2,709 of 2,714 buffers in one core, and 34,354 in a worse one
- `src/init.lua` — the watchdog `stampede`: a starved core owes one timer fire per missed
  interval, and each fire costs a /proc read, a buffer walk, and a log append. the guard becomes
  the load, and its rate rises with the starvation it worsens
- the keyrack daemon leak — 641 leaked daemons filled zram, which forced disk swap, which
  slowed every process, which leaked more daemons per commit

**the origin:**

- 2026-09-02 — the human asked "which of them infigrows?" and "which of them is a negative
  reinforcer?". those two questions name this concept exactly, and it had no word until now

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **amplifier** | output re-enters input; gain is a property of the mechanism | ✅ names the relation and its cause |
| `feedback-loop` | any loop, a self-correcting one included | ✗ too broad — a thermostat is a feedback loop |
| `spiral` | a shape, with no account of mechanism | ✗ describes the curve, not the cause |
| `snowball` | growth by accretion from outside | ✗ an amplifier needs no external input |
| `vicious-cycle` | a moral judgment on an outcome | ✗ names the harm, not the structure |
| `cascade` | one failure triggers the next, in a chain | ✗ a cascade moves forward; an amplifier returns |

## .reason

see the ref-level file beside this choice:

- `term=amplifier._.choice.reason.md` — etymology, the three instances in full, and the guard
  that each one had and lost
