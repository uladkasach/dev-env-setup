# domain.term: census

term.chosen   = census
term.kind     = noun
term.synonyms.forbidden:
- top
- rank
- leaderboard
- summary

## .what

a count of the **whole** population, grouped by class, where the class is the unit of interest
and no member is dropped.

what defines a census is **totality and grouped attribution**: every process is counted, and the
count is charged to a name rather than to a pid. a census answers *who holds it, as a class*.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — the `census:` row, one awk
  pass over `/proc/*/comm` + `/proc/*/statm`, grouped by comm

**the origin:**

- 2026-08-30 — 13 `claude` processes held 8.7 GB (~47% of memory in use) while each sat near 3%,
  so every per-process top-N ranked them low or omitted them

## .the boundary that makes this term carry weight

**`top` is forbidden because it ranks members, and a class can dominate with no member ranked.**

| word | what it counts | can it see a diffuse class? |
|------|----------------|-----------------------------|
| **census** | every member, grouped by class | ✅ — that is its definition |
| `top` | the N largest members | ✗ — 13 × 3% never enters a top-15 by share |
| `rank` | order among members | ✗ — same blind spot, plus implies a contest |
| `leaderboard` | the winners | ✗ — the largest holder here has no "winner" |
| `summary` | unbounded, undefined method | ✗ — names no contract |

the counter-example that settles it: a `top 15 mem` listed 12 `claude` rows individually at
1.5–3.4% each. a reader scans it and concludes memory is diffuse. the census renders one row —
`claude 13 procs 8.7G` — and the largest holder on the box becomes obvious at a glance.

## .a census is total, so it must be cheap

totality is the property, so the cost of the count must not scale with a fork per member. the
contract reads `/proc/*/comm` and `/proc/*/statm` in a **single awk pass** — no `ps` per pid, no
subshell per process. a census that costs a spawn per member would perturb the very population it
counts.

## .reason

see the ref-level file beside this choice:

- `term=census._.choice.reason.md` — etymology, the blind spot it names, the SIGPIPE trap
