# domain.term.choice.reason: watchdog

## .etymology

from the hardware **watchdog timer** — a counter that reboots the board unless the software
periodically pets it. the software half of the name is inverted from the hardware one: hardware
watchdogs assume silence means death and act on the silence; a software watchdog observes an
active signal and acts on its value.

what carries across, and what earns the word, is the **autonomy**. no one asks a watchdog for a
verdict. it decides on its own schedule and acts without a caller. that is the property `monitor`
and `healthcheck` both lack.

## .the case that pinned it

2026-09-02. sixty-one trips on record, over six weeks:

```
2026-07-23T12:25:43 TRIP rss_mb=1200 pid=2289594 — disabled minimap+treesitter
2026-08-12T03:18:39 TRIP rss_mb=1282 pid=1987534 — disabled minimap+treesitter
2026-09-02T11:00:38 TRIP rss_mb=1208 pid=3718338 — disabled minimap+treesitter
```

every trip lands in a 99M band just above the 1200M line, which says the breaker catches the
climb within one tick — the mechanism works. and every trip carries a **different pid**, which
says the population is the problem, not any member of it. the same shape the `class` profile
found for claude, read here from a different instrument.

## .why the breaker self-heals and never self-kills

a watchdog could kill its host. this one does not, and the reason is the whole design:

> the buffers hold unsaved human work. a kill is cheap for the machine and expensive for the
> human, so the breaker gives up the machine's comforts (minimap, syntax parsers) and keeps the
> human's state.

a systemd `MemoryHigh=1.5G` scope sits underneath as the backstop. the two layers are deliberate:
the watchdog trips first and softly at 1.2G, and the kernel throttles hard at 1.5G only if the
soft measure failed. so the watchdog's job is to make the hard limit unreachable, not to enforce
one.

## ⚠️ .the case where it disabled the wrong subsystem

the breaker runs `Neominimap off` plus `vim.treesitter.stop` on every buffer. the trend log says
that remedy misses both observed leak modes:

| core | rss | bufs | ts | what the breaker did |
|------|-----|------|-----|----------------------|
| pid 3718338 | 1208M | **14,691** | **0** | stopped treesitter (already 0), left 14,691 buffers |
| a live core | 1126→1143M | **90 flat** | **0 flat** | would stop two subsystems, neither of which grew |

in the first the breaker acted on a dimension already at zero. in the second neither instrumented
dimension moved at all, so the growth has no attributable owner and the breaker has no lever.

this is why the diagnose skill reports **which dimension moved**, and names an `UNATTRIBUTED`
mode explicitly rather than fall through to a default. a remedy applied to the wrong subsystem
is worse than no remedy: the human disables minimap, sees no change, and no longer trusts the
tool.

> **the durable lesson: a breaker must instrument what it disables, and disable what it
> instruments.** where the two sets differ, the gap is exactly the failure it cannot catch — and
> the report must name that gap rather than imply coverage.

## ⚠️ .a watchdog can be present and inert

three ways this one was live and not helpful, all found in one round:

1. **it stampeded** — 40 fires in one second, because the repo's cadence guard was never synced
   to the machine (see `term=stampede`)
2. **its log outgrew its cap** — 7.7MB against a 2MB cap, because the rotation was likewise
   never synced. the guard against a log burden became a log burden
3. **its remedy missed the leak** — as above

each failure is silent. the watchdog exists, its timer fires, its log grows — every surface sign
reads healthy. only the log's *contents* reveal it.

> **read the log, never the existence.** a mechanism's presence is not evidence of its function,
> and a self-monitor is exactly the mechanism where that mistake is easiest to make.

## .disputes

none raised. `monitor` was the only real contender and it lost on two counts: it is silent about
the act (a monitor reports; a watchdog trips), and it does not imply the inside-ness that gives
this mechanism both its unique visibility and its shared fate.

## .the neighbours

- **`stampede`** — what a watchdog does when its host is starved. any repeat timer can stampede;
  a watchdog is the case that matters most, because it exists to help under load and instead
  adds load.
- **`leak`** — what a watchdog exists to catch. the trend log's three dimensions are precisely
  an attempt to attribute a leak, and the `UNATTRIBUTED` case is where that attempt fails.
- **`class`** — 61 trips across 61 pids is a class fact, not a member fact. the same read the
  census makes by name, the trip log makes by time.
- **`concern`** — the watchdog's trip is itself a concern in `machine.usage.diagnose`. the report
  quotes the watchdog's verdict rather than re-derive it, because the watchdog can see inside and
  the report cannot.
