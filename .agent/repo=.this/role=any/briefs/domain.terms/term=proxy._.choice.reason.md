# domain.term.choice.reason: proxy

## .etymology

latin *procuratio* — care on another's behalf; contracted through anglo-french to *proxy*, one
who acts with another's authority. the legal sense is the useful one: a proxy **carries an
authority that can be checked**, and its acts are void where that authority does not reach.

that is exactly the discipline a measured proxy needs. duration carries the authority of progress
only where work is expected to end. ppid carries the authority of agency only while the parent
lives. the word already implies a scope of delegation, and a scope is precisely what these
defects omit.

`heuristic` was the nearest contender and it fails here: a heuristic is *known* to be imprecise
and is used anyway, with the imprecision priced in. a proxy is presented as the fact itself. the
distinction is accountability, and the latin sense carries it.

## .the eight instances

each shipped a confident, actionable string aimed at the wrong target. all eight are this repo's
own diagnostics, over three days:

| # | contract | the proxy | claimed to be | how it broke |
|---|----------|-----------|---------------|--------------|
| 1 | `machine.usage.diagnose` | duration | no progress (`wedged`) | 3 healthy sessions indicted, `kill -9` offered |
| 2 | `machine.diagnose.class` | sort order (age) | the cost axis the advice named | told the human twice to close the *cheapest* sessions |
| 3 | `machine.diagnose.class` | `0` default | a measured transcript size | "transcript is small (0M)" — it was 435M |
| 4 | `machine.diagnose.churn` | ppid | the party that acted | ranked init first, advised "cut pid=1" |
| 5 | `nvim.diagnose.watchdog` | line count × 30s | elapsed time | 0s span read as 20 min → "0.9M/min" |
| 6 | `nvim.diagnose.watchdog` | `SECS == 0` | a compressed window | a 1s burst slipped the equality → "1020M/min", eta "-0 min" |
| 7 | `nvim.diagnose.watchdog` | field position (`$4`) | field identity | printed `rss=pid=618858` once the format grew |
| 8 | `nvim.diagnose.watchdog` | string compare | numeric compare | `999M peak / 1004M floor` — a peak below its own floor |

#5 deserves a second look: **the tool that reports a stampede was itself fooled by one.** its rate
rested on a cadence the stampede had already broken. a proxy fails in the case it was built to
diagnose, because that case is the one where its condition does not hold.

## .the shape they share

each substitution was correct **under an assumption that held while the machine was calm**:

| the proxy | the silent assumption |
|-----------|----------------------|
| duration → progress | the work is expected to end |
| ppid → agency | the parent is alive |
| line count → time | the timer keeps cadence |
| `SECS == 0` → compressed | a burst never straddles a second boundary |
| position → identity | the format never grows |
| string order → magnitude | the values never cross a digit-count boundary |

not one is unreasonable. every one is unrecorded. and every one fails in the emergency the tool
exists to diagnose — because an emergency is, definitionally, where normal conditions stop.

> **a proxy fails in the case it was built to diagnose.** that is not bad luck. the assumption
> that licenses the substitution is the same normality the emergency suspends.

## .why this was promoted from a lesson to a rule

after four instances i recorded the pattern in `progress.md` and **deferred** the rule brief as
"more than this round can finish honestly." four more arrived in the next session — in code i
wrote *while* i held the pattern in mind.

that is the argument for the promotion. a lesson in a progress log is read by whoever reads that
log; a rule in `briefs/` is a check a reviewer can invoke by name. the deferral was defensible at
four and dishonest at eight, so the rule now exists:
`rule.require.name-what-you-measured`.

## .the discipline, stated

for every number a report prints, three questions:

1. **what did i actually measure?** — the literal quantity the instrument returned
2. **what does the sentence claim?** — the quantity the prose asserts
3. **what makes (1) equal (2)?** — the condition; if it cannot be named, there is no proxy, only
   a guess

when (1) and (2) differ, the condition is a proxy and it belongs in a `.note`. when the condition
can fail in a case the tool exists to catch, the report must **detect that case and refuse to
print the number**, rather than print it with a caveat. a caveat is read after the number; a
refusal cannot be misread.

## .disputes

none raised. the boundary against `heuristic` and `approximation` is argued in the say file, and
both losses turn on the same point: those words describe a *known, priced* imprecision, whereas a
proxy defect is an *unstated* substitution. the whole hazard is the silence.

## .the neighbours

- **`concern`** — every one of the eight instances shipped inside a concern's `says` or `fix`.
  the mandatory-fix field is what made them actionable, and so what made them harmful.
- **`stall`** / **`churn`** / **`class`** — each replaced a proxy with a direct measurement: psi
  measures the wait rather than infer it from load; a fork rate measures births rather than infer
  them from `ps`; a correlation measures leak-vs-headcount rather than assume age predicts cost.
  the good diagnostics in this repo are exactly the ones that removed a proxy.
- **`failhide`** — the adjacent failure. a failhide prints a wrong verdict from an absent
  measurement; a proxy defect prints a wrong verdict from a real measurement of the wrong
  quantity. both read as confident, and both need the same cure: state what was measured.
