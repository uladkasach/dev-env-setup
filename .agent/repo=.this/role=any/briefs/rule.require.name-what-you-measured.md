# rule.require.name-what-you-measured

## .what

for every number a report prints, the quantity **measured** and the quantity **claimed** must be
the same — or the substitution between them must be stated, and the case where it fails must be
detected rather than caveated.

a value substituted for another is a `proxy`. proxies are legitimate and often unavoidable.
an **unstated** proxy is a defect.

## .why

eight shipped defects in this repo's own diagnostics, over three days, are all one shape. each
printed a confident, actionable string aimed at the wrong target:

| the contract | measured | claimed | the result |
|--------------|----------|---------|------------|
| `machine.usage.diagnose` | duration | no progress | indicted 3 healthy sessions, offered `kill -9` |
| `machine.diagnose.class` | sort order (age) | the cost axis | advised a close of the *cheapest* sessions, twice |
| `machine.diagnose.class` | `0` default | a measured size | "transcript is small (0M)" — it was 435M |
| `machine.diagnose.churn` | ppid | the party that acted | ranked init first, advised "cut pid=1" |
| `nvim.diagnose.watchdog` | line count × 30s | elapsed time | 0s span read as 20 min → "0.9M/min" |
| `nvim.diagnose.watchdog` | `SECS == 0` | a compressed window | a 1s burst → "1020M/min", eta "-0 min" |
| `nvim.diagnose.watchdog` | field position | field identity | printed `rss=pid=618858` |
| `nvim.diagnose.watchdog` | string compare | numeric compare | peak below its own floor |

none of these is a typo. each is a substitution that was **correct under an assumption the author
held and did not record**. and each assumption fails in the emergency the tool exists to
diagnose — because an emergency is, definitionally, where normal conditions stop.

> **a proxy fails in the case it was built to diagnose.** the assumption that licenses the
> substitution is the same normality the emergency suspends.

the sharpest instance: the skill that reports a *stampede* computed its rate from a cadence a
stampede breaks. the tool was fooled by what it reports.

## .the three questions

for every number a report prints:

1. **what did i actually measure?** — the literal quantity the instrument returned
2. **what does the sentence claim?** — the quantity the prose asserts
3. **what makes (1) equal (2)?** — the condition

if (3) cannot be named, there is no proxy — only a guess, and the number must not be printed.

## .the two obligations

when (1) and (2) differ:

**state it.** the condition goes in a `.note` beside the code, in the timeless form
(`rule.require.timeless-comments`) — what holds, and where it stops.

**detect its failure.** where the condition can break in a case the tool exists to catch, the
report must **refuse to print the number**, not print it with a caveat. a caveat is read after
the number has already landed; a refusal cannot be misread.

```sh
# 👍 the refusal
if [[ "$BURST" -eq 1 ]]; then
  echo "rss: ${R0}M → ${R1}M   (+${D_RSS}M, rate unknowable)"
else
  echo "rss: ${R0}M → ${R1}M   (+${D_RSS}M, ${RATE}M/min)"
fi
```

## .the five forms that recur

these account for all eight instances. check each by name:

| form | the trap | the cure |
|------|----------|----------|
| **duration → state** | long-lived reads as stuck | measure the state's own clause (a tty, a progress marker) |
| **count → time** | n events × cadence = elapsed | subtract two timestamps |
| **position → identity** | `$4` is the rss field | read by name; a format grows |
| **default → measurement** | `0` means absent *and* zero | a separate `_FOUND` flag |
| **an equality on a continuum** | `SECS == 0` matches one value only | a range, scaled to the quantity |

## .the corollary: a sort order is a claim

an ordered list asserts that its order is the axis its advice names. a reader acts on the first
row. so a list sorted by age beneath advice about cost has made a recommendation no one wrote.

sort by the axis the advice names, or state the axis in the header.

## .the test

read the sentence and the number as a stranger. ask: "does the number prove the sentence, or
merely accompany it?"

- proves → the measurement and the claim are the same quantity
- accompanies → there is a proxy; name it, and detect its failure

## .enforcement

- a printed number whose measured quantity differs from its claimed quantity, with no stated
  condition = **blocker**
- a proxy whose failure case is reachable in the tool's own domain, with no detection = **blocker**
- an ordered list whose order differs from the axis its advice names = **blocker**
- an equality test used to detect a range on a continuous quantity = **blocker**

## .see also

- `domain.terms/term=proxy._.choice._.md` — the term this rule enforces
- `rule.forbid.failhide` (mechanic) — the adjacent failure: a wrong verdict from an *absent*
  measurement, where this is a wrong verdict from a real measurement of the wrong quantity
- `rule.require.timeless-comments` — the form the stated condition takes
- `rule.require.entool-never-adhoc` — a skill can be corrected; an ad-hoc probe carries its
  proxies unreviewed
