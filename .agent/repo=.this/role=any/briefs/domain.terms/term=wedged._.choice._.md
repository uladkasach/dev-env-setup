# domain.term: wedged

term.chosen   = wedged
term.kind     = adj
term.synonyms.forbidden:
- hung
- stuck
- zombie
- runaway
- busy

## .what

a process that is **alive, consumes cpu, and makes no progress**.

the three parts are jointly required. a wedged process is not asleep and not dead — it burns real
cycles — yet it will never finish, so every cycle it takes is taken from work that would.

the observable signature is the pair no single metric carries: **long elapsed AND still active**.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — the 🪤 concern; predicate is
  `etimes > 86400 && pcpu > 5.0`

**the origin:**

- 2026-08-30 — `npm run test:integration`, `elapsed=147h36m`, 10.6% cpu, on a box whose uptime
  was 6d3h — wedged for essentially the entire boot, and respawned children the whole time

## .the boundary that makes this term carry weight

**every nearby word names one half of the pair, and each half alone is a healthy state.**

| word | what it names | why it fails |
|------|---------------|--------------|
| **wedged** | alive + on cpu + no progress | ✅ the conjunction is the defect |
| `hung` | unresponsive, usually **off** cpu | ✗ omits the cost; a hung proc may be free |
| `stuck` | blocked, waits on a resource | ✗ a blocked proc yields its core |
| `zombie` | **dead**, exit status unreaped | ✗ the unix sense; a wedged proc is alive |
| `runaway` | high cpu right now | ✗ true of legitimate new work too |
| `busy` | at work | ✗ the healthy case reads identical |

`zombie` deserves the sharpest line: in unix it already denotes a *dead child whose parent has
not waited*. a wedged process is the opposite — very much alive, and that is precisely why it
costs. to reuse `zombie` would overload a term the platform already owns.

## .why neither a cpu nor a memory threshold can catch it

a wedged process is often **modest** on every instantaneous axis — 10% of a core, small RSS. it
clears no alarm. what indicts it is duration: 10% of a core for 147 hours is ~15 core-hours spent
on work that will never land.

so the detector cannot be a level. it must be the conjunction `elapsed > 24h AND pcpu > 5%`,
which is the only shape that separates a wedged process from both a healthy daemon (long-lived,
near-idle) and a healthy build (busy, short-lived).

## .reason

see the ref-level file beside this choice:

- `term=wedged._.choice.reason.md` — etymology, the 147-hour case, the reinforcement it feeds
