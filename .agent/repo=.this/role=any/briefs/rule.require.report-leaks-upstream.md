# rule.require.report-leaks-upstream

## 🛑 .the rule, in one line

# **WHENEVER YOU TOUCH PERFORMANCE, CENSUS THE LEAK POPULATIONS. IF ONE IS NON-ZERO, NAME ITS ALLOCATOR AND OFFER THE UPSTREAM FIX.**

a prune is a **chore**, never a fix. it bounds a population and stops no mint. so a
population found bounded-and-refilling is not a closed matter — it is an open upstream
defect that somebody is paying rent on, every fifteen minutes, forever.

## .why the count IS actionable

the leaking allocators are **ours**. rhachet owns keyrack, owns `keyrackd`, and owns
every caller that mints one:

| origin | the allocator | whose |
|---|---|---|
| `jest.tmpdir.dash` / `jest.tmpdir.slash` | the jest fixture's throwaway `$HOME` | rhachet |
| `git.push.temphome` | `genTempDir` under `git.push` | rhachet |
| `git.set.temphome` | `genTempDir` under `git.set` | rhachet |

⇒ so *"575 daemons over 76 days"* is not a shrug. it is the **severity** that justifies
the fix, addressed to the team that can make it. and the origin breakdown is the
**location**. a report with one and not the other is half a report.

⚠️ the reflex to resist is *"we already know it leaks, so the number adds no value."*
that reasoning ends in a prune that runs forever and an allocator nobody ever fixed.

## 🛑 .a leak that RETURNS is a REGRESSION, and it earns a FRESH report

this is the clause the rule exists for. once an allocator is fixed, its origin should
fall to zero and stay there. so a non-zero count for a **previously fixed** origin is
not the old news — it is new information:

> **something went wrong upstream, and the fix did not hold.**

⇒ report it again, as a regression, with the date it was last seen at zero. do NOT
absorb it into the prune's normal run and call the matter handled. the prune's success
at bounding the pool is exactly what makes a regression easy to miss.

## .when this fires

any round whose subject is performance — a slow box, a memory hunt, a swap incident, a
latency diagnosis, a `machine.usage.diagnose` read. the census is cheap:

```sh
keyrack.daemon.prune.sh --census      # daemons, by spawn path
tmp.fixture.prune.sh                  # the twin population
```

⚠️ a **timer-run prune already prints the origin breakdown** on every apply, so the
journal holds the history. read it before you census by hand:

```sh
journalctl --user -u keyrack_daemon_prune.service --since '7 days ago'
```

## .what a report owes

1. **the population** — how many, over what window (the severity)
2. **the origin breakdown** — which allocator, in what proportion (the location)
3. **the cost** — PSS and swap, since ANON memory must swap rather than be reclaimed
4. **whether this origin was previously fixed** — if yes, say REGRESSION in the title
5. **the offer** — name the allocator fix, and offer to make it

## .the offer is not optional

the round ends with an OFFER to fix upstream, not merely a report of the finding. the
fix is one allocator that reaps its fixture on exit, and it closes both populations at
once — a throwaway `$HOME` *is* a tmp fixture, and a daemon keyed on it is what that
fixture leaks (`term=daemon`, `term=tmp.fixture`).

## .enforcement

- a performance round that ran a prune and did NOT census the origins = **blocker**
- a non-zero population reported with a count and no origin breakdown = **blocker**
- a non-zero count for a previously-fixed origin, reported as routine rather than as a
  REGRESSION = **blocker**
- a prune described to a human as the fix = **blocker**; it is a chore that bounds a
  pool, and to call it a fix retires an upstream defect that is still live
- a performance round that names an allocator and does not OFFER the upstream fix =
  **nitpick**

## .see also

- `term=daemon._.choice.reason.md` — `.the fix belongs in the ALLOCATOR, and the prune
  is a chore`
- `term=tmp.fixture._.choice._.md` — the twin population, one allocator behind both
- `hazard.idle-process-leak-crosses-the-swap-cliff.md` — what the population costs
- `rule.require.solve-at-cause` — a prune treats the symptom
- `rule.require.name-what-you-measured` — the count is a claim about a set
