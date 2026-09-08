# domain.term: breaker

term.chosen   = breaker
term.kind     = noun
term.synonyms.forbidden:
- watchdog     (names the OBSERVER. a breaker CUTS — the watchdog is the timer that reaches for
                it. `selfwatch` is the observer half and keeps its own word)
- killswitch   (implies the program halts. a breaker disables MACHINERY and the program runs on —
                that survival is the entire point)
- limiter      (implies a continuous throttle. a breaker fires ONCE, at a threshold, and latches)
- reaper       (names a sweep on a schedule. a breaker fires on a condition, never on a clock)
- gc           (already means lua's collector here, which a breaker CALLS — to reuse the word
                would name the breaker after one of its own steps)

## .what
a guard **inside a live process** that watches its own resource use and, at a threshold,
disables machinery and reclaims what that machinery held — so the process survives rather than
dies to an out-of-band kill.

```
   nvim selfwatch: rss ≥ 1.2GB  →  trip
      ├─ disable neominimap
      ├─ stop treesitter on every buffer
      ├─ reclaim what they held
      └─ notify, and log the before/after census
```

⚠️ it **latches** by design: `tripped` is set before the first cut, so it fires once per process.
a breaker that re-fires is a throttle, and a throttle that disables machinery is an outage.

## 🛑 .a breaker RECLAIMS, so its predicate is a DESTRUCTIVE contract

this is the split the word turns on, and the one that cost this repo a live defect.

| the artifact | reclaimable |
|---|---|
| **leaked** — the machinery made it, and will make another | yes |
| **structural** — the machinery made it ONCE and caches the id forever | **no** |

a predicate that names only the machinery's own artifacts matches BOTH. the plugin cannot tell
you which is which: from outside they share a filetype, a buftype, and an unmodified flag.

⇒ **a breaker owes an exclusion list, not merely a predicate.** what it must not touch is a
separate fact from what it may.

✔ **measured 2026-09-06**, headless, both arms, against the live `~/.config/nvim/init.lua`:

```
ARM=control  empty_buffer=2 valid_after=true   refresh_ok=true
ARM=break    empty_buffer=2 valid_after=false  refresh_ok=false
             err=…neominimap/window/split/internal.lua:159: Invalid buffer id: 2
```

`ft == 'neominimap' and not modified` matched 2,709 leaked buffers **and** the one scratch
buffer `buffer/internal.lua:25` creates at module load and holds as a bare integer. one wipe,
and every later refresh threw for the life of the session.

## ⚠️ .a breaker's REMEDY must be measured, never assumed

`collectgarbage` frees lua-managed memory only, so on a native leak it reclaims 0MB while the
notification still claims a remedy. the live breaker records a before/after census for exactly
this reason — so its log states which happened, and a reader can tell a breaker that works from
a ceremonial one.

⇒ a breaker that reports a remedy it did not deliver is `rule.forbid.failhide` dressed as a
notification. the first cut of this one accrued **63 trips** while the leak it fired over stayed
untouched.

## .refs
- `src/grove.provision/4.terminal/4.5.nvim/init.lua` — `trip_breaker`, the one breaker declared here
- `~/.local/state/nvim/selfwatch.log` — the trend log the observer half writes
- `term=live._.choice._.md` — a breaker acts on LIVE state, so its verdict never survives a boot

## .reason
see the ref-level cluster beside this choice:
- `term=breaker._.choice.reason.md` — etymology, the `watchdog` dispute, the leaked/structural evidence
