# domain.term: watchdog

term.chosen   = watchdog
term.kind     = noun
term.synonyms.forbidden:
- monitor
- guard
- sentry
- supervisor
- healthcheck

## .what

a **self-monitor that lives inside the process it watches**, and that trips a breaker on itself
when a threshold is crossed.

both clauses carry weight:

1. **inside** — it observes its own `/proc/self`, not another process's. so it sees what no
   external tool can (buffer counts, attached parsers, internal state), and it is subject to the
   same starvation as its host
2. **trips a breaker** — it acts, it does not merely report. the act is self-heal, never
   self-kill: the nvim watchdog disables its heaviest subsystems and keeps the buffers

what makes it worth a word rather than a description: a watchdog's **failure modes are its
host's**. an external monitor still observes a wedged process; a watchdog wedges with it,
stampedes with it, and leaks with it. every guarantee it offers holds only while its host stays
schedulable at all.

## .refs

**the contracts:**

- `src/init.lua` — the nvim self-watchdog: a 30s `vim.uv` timer that reads `/proc/self/status`,
  logs a trend past 800M, and trips at 1200M via `trip_breaker`
- `.agent/repo=.this/role=any/skills/nvim.diagnose.watchdog.sh` — reads the watchdog's trend log
  and attributes the growth to the dimension that moved with it
- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — the `nvim:` row, which reports
  the watchdog's verdict rather than a re-derivation of it

**the origin:**

- 2026-09-02 — 61 trips on record, each at 1200–1299M, each a **different pid**. the count made
  the shape plain: not one defective core, but every core, one at a time

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **watchdog** | inside, autonomous, acts on its host | ✅ both clauses carried |
| `monitor` | observes and reports; may be external | ✗ silent on the act, and on the inside-ness |
| `guard` | blocks entry at a boundary | ✗ a watchdog admits all input, then reacts |
| `sentry` | watches an outside for an intruder | ✗ the threat is internal |
| `supervisor` | manages children from above | ✗ a watchdog has no children and no altitude |
| `healthcheck` | an external prod, answered on demand | ✗ pull vs push, and outside vs inside |

`healthcheck` draws the sharpest line: a healthcheck is asked and answers; a watchdog is asked
by no one and acts unprompted. that difference decides who is accountable when it fails silently.

## ⚠️ .the property that bites

a watchdog shares its host's fate. so it inherits three defects the host has:

- **starvation** → the watchdog stampedes (see `term=stampede`)
- **a leak the watchdog does not instrument** → the breaker trips and cannot help
- **an un-synced config** → the guards exist in the repo and not on the machine

each of these makes the watchdog look present and effective while it is neither. read its log,
never its mere existence, as the evidence that it works.

## .reason

see the ref-level file beside this choice:

- `term=watchdog._.choice.reason.md` — etymology, why the breaker must self-heal rather than
  self-kill, and the case where it disabled the wrong subsystem
