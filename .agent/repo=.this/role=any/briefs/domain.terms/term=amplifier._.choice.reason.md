# domain.term.choice.reason: amplifier

## .etymology

latin *amplificare* — to enlarge. the electronics sense is the precise one: an amplifier has a
**gain**, and when its output is routed back to its input the gain compounds. that is exactly the
structure here, and it is why the word beats every metaphor.

the metaphors all describe the *curve* (`spiral`, `snowball`) or the *outcome*
(`vicious-cycle`). only `amplifier` names the *mechanism*: there is a path from output to input,
and the fix is to cut that path. a word that names the cure is worth more than one that names the
symptom.

## .the three instances

### 1. the minimap of a minimap

a minimap is a `nofile` scratch buffer. neominimap's default `exclude_buftypes` holds `nofile`,
so by default a minimap can never be given a minimap.

this repo emptied that list, for a good and stated reason — codediff's diff panes are `nofile`
and must be mapped. the removal also made every minimap eligible for a minimap of its own.

measured 2026-09-03 in one live core:

```
1367  neominimap  nofile  scratch  loaded
1342  -           nofile  scratch  loaded
   5  everything else
```

2,709 of 2,714 buffers. the near 1:1 split between typed and not-yet-typed rows is the signature
of a map made per map. `--history` showed 34,354 buffers in a worse core. 63 watchdog trips, over
six weeks, all downstream of one emptied list.

### 2. the watchdog stampede

libuv owes a missed timer interval rather than skips it. a core starved for 20 minutes on a 30s
timer wakes owing 40 fires and pays them all at once — each a /proc read, a buffer walk, and a
log append, imposed on a machine already too contended to schedule it.

the gain here is subtle and worse: **the more starved the core, the more fires it owes**, and
each fire deepens the starvation. the guard against a leak becomes a load, and its magnitude
scales with the emergency.

### 3. the keyrack daemon leak

641 leaked daemons filled zram, which forced swap to disk, which slowed every process, which
made each commit slower, which leaked more daemons per commit. the loop closed through the
machine rather than through one process — which is why no per-process instrument saw it.

## .the shape they share: a guard that was removed, or never known

each instance had a guard, and lost it:

| instance | the guard | how it was lost |
|----------|-----------|-----------------|
| minimap | `exclude_buftypes` held `nofile` by default | emptied on purpose, for codediff |
| stampede | a cadence check on the timer | written in the repo, never synced to the machine |
| daemons | a reap on exit | never existed |

the first is the instructive one, because the removal was **correct**. codediff's panes genuinely
need mapping. the defect was not the removal; it was that the default carried **two** jobs and
only one was known:

- the job we knew: keep minimaps off scratch buffers
- the job we did not: keep minimaps off *minimaps*

> **a default is a guard someone else wrote, and it may guard more than one hazard.** to remove
> one for a reason is fine; to remove it without an enumeration of what it held is to inherit an
> unknown liability. state what the default protected, then remove only the clause you mean to.

the fix follows that shape exactly: rather than restore the broad `exclude_buftypes`, name the
narrow clause — `neominimap` in `exclude_filetypes`. minimaps stay off minimaps; codediff keeps
its maps. the guard is re-established at the precise width intended.

## .why the breaker could not help

`Neominimap off` hides minimap **windows**. it deletes no buffers. so the breaker fired 63 times,
reported a remedy each time, and left the leak untouched — the memory it tripped over stayed
held.

this is the amplifier's second signature: **a remedy aimed at the symptom leaves the loop
intact**, so the trip recurs on a fixed period forever. sixty-three trips is not sixty-three
problems; it is one problem, unaddressed, sixty-three times.

> **a repeated trip is evidence the remedy misses.** a breaker that fires once is a breaker that
> worked. a breaker that fires weekly is a breaker whose lever is attached to the wrong thing.

## .how to find one

an amplifier hides from every source-hunt, because the source is the mechanism. the tells:

1. **a class grows while no member is large** — cost is in the population, not the individual
2. **the count is a near-multiple of another count** — 1:1 with buffers named a map per map
3. **a kill helps, then it returns on a schedule** — the loop survives its members
4. **the rate rises with the load** — the strongest tell, and the most dangerous

`machine.diagnose.class` finds (1) and (2). the watchdog trip record finds (3). (4) needs two
samples at different load levels, which no current skill takes — recorded as an open gap.

## .disputes

none raised. `feedback-loop` was the nearest and lost on breadth: a thermostat is a feedback
loop, and a word that covers both the stabilizer and the amplifier cannot carry a warning.
`runaway` was the collision risk, and is handled explicitly in the say file — member versus
relation.

## .the neighbours

- **`runaway`** — the boundary case; see the table in the say file. a runaway is one process, an
  amplifier is a relation.
- **`leak`** — what an amplifier produces. `leak` names unbounded growth; `amplifier` names the
  structure that causes it. a leak can be linear (a missed reap); an amplifier's is not.
- **`stampede`** — one specific amplifier: the timer debt. it is a member of this concept, and
  keeps its own word because its mechanism (an owed interval) and its fix (a cadence guard) are
  particular.
- **`class`** — the instrument that finds an amplifier, because an amplifier's cost lands on a
  population rather than a member.
- **`watchdog`** — both a victim (it stampedes) and a would-be cure (its breaker), which is why
  this term's lessons landed in that one's file too.
