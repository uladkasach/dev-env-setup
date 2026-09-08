# domain.term: breaker.trip

term.chosen   = breaker.trip
term.kind     = verb
term.synonyms.forbidden:
- fire         (says the threshold was crossed and says none of what followed. a trip is the
                whole act — disable, reclaim, report — not the signal that starts it)
- panic        (names an abort. a trip exists so the process does NOT abort)
- cut          (names one step of three. the reclaim and the report are equally the trip)
- activate     (generic, and it reads as an enable where a trip DISABLES)

## .what
fire the breaker: disable the machinery under suspicion, reclaim what it held, and report the
before/after census. declared as `trip_breaker`, called from the selfwatch timer at exactly one
site.

## .the three steps, and all three are the trip
1. **disable** — the machinery stops, so it adds no more
2. **reclaim** — what it already made is released
3. **report** — a notification, plus a census line that names what the reclaim actually returned

⚠️ step 3 is not decoration. a trip that reports a remedy it did not deliver is
`rule.forbid.failhide`, and this one shipped that way — see `term=breaker._.choice.reason.md`.

## .it fires ONCE per process
the latch (`tripped`) is set before step 1, so a later threshold cross is a no-op. a trip that
repeats is a throttle, and a throttle that disables machinery is an outage.

⇒ so a trip's damage is **permanent for that session**. it is not a state the process recovers
from — the only reset is a restart. that is what makes step 2's predicate a delete contract
rather than a cleanup.

## .refs
- `src/grove.provision/4.terminal/4.5.nvim/init.lua` — `trip_breaker`, the sole declaration
- `term=breaker._.choice._.md` — the object this verb acts on, and the leaked/structural split

## .reason
see the ref-level cluster beside this choice:
- `term=breaker.trip._.choice.reason.md` — why the verb is spelled with its object, and why
  `fire` lost
