# domain.term: stampede

term.chosen   = stampede
term.kind     = noun
term.synonyms.forbidden:
- storm
- burst
- flood
- backlog
- pileup

## .what

a **backlog of timer fires released at once**, after the process that owed them was starved of
cpu long enough to miss its intervals.

a repeat timer under libuv (and most event loops) does not skip a missed interval — it owes it.
when the process is finally scheduled, every owed fire lands in the same instant. so a core
unscheduled for 20 minutes on a 30-second timer wakes to a debt of 40 fires, and pays all 40
inside one second.

three properties make it worth its own word:

1. **retrospective** — the fires are owed from the past, not generated now
2. **self-inflicted by the monitor** — the guard against a defect becomes a load of its own,
   at the exact moment the machine can least afford it
3. **it destroys the time axis** — every fire timestamps to the same second, so any rate derived
   from a fire count across a stampede is fiction

## ⚠️ .not a synonym of `churn`

this is the boundary that earns the word. both name "many events fast", and `storm` is already a
**forbidden synonym of `churn`** — so a new word here needs to survive the overload test.

| | `churn` | `stampede` |
|---|---|---|
| what repeats | process **births** | timer **fires** |
| how many actors | many processes | **one** process |
| tense | present — a rate observed now | **retrospective** — a debt from the past |
| the fix | find the parent, cut the spawn source | restore the cadence guard, or relieve the starvation |

a churn measurement is valid because its window is real. a stampede measurement is not, because
its window collapsed to a point. that difference is not stylistic — it decides whether a rate
can be computed at all.

## .refs

**the contracts:**

- `.agent/repo=.this/role=any/skills/nvim.diagnose.watchdog.sh` — the `🔥 STAMPEDE` concern, and
  the `SECS -eq 0 && N -ge 10` predicate that detects it
- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — the `watchdog STAMPEDE` row
  state, which suppresses the rate rather than print a false one
- `src/init.lua` — the `last_run_s` guard that drops any fire that lands early

**the origin:**

- 2026-09-02 — 40 watchdog trend lines shared one timestamp (`13:28:28`). the repo comment had
  already recorded the phenomenon ("observed: 40 fires inside a single second") and shipped a
  guard for it; the guard had never reached the machine, so the event recurred

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **stampede** | a held-back mass released at once, by pressure that built up | ✅ the debt and the release are both carried |
| `storm` | ⛔ already a forbidden synonym of `churn` — reuse would overload it | ✗ |
| `burst` | a fast group, with no account of why | ✗ silent on the debt, which is the whole cause |
| `flood` | volume from a source | ✗ implies more input; a stampede has no new input |
| `backlog` | the debt at rest | ✗ names the queue, not its release — the release is the defect |
| `pileup` | a collision, an accident | ✗ each fire is correct; only their coincidence is the defect |

## .reason

see the ref-level file beside this choice:

- `term=stampede._.choice.reason.md` — etymology, why a stampede voids a rate, the defect it
  caught in my own instrument
