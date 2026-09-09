# domain.term: proxy

term.chosen   = proxy
term.kind     = noun
term.synonyms.forbidden:
- heuristic
- approximation
- stand-in
- signal
- indicator

## .what

a value a report **measures**, substituted for the value a report **claims**.

a proxy is not a defect. it is often the only measurable option — no instrument reads "progress",
so duration substitutes; no instrument reads "the party that acted", so ppid substitutes. the
proxy is how a diagnostic exists at all.

the defect is a proxy **left unstated**. once the substitution is silent, the report asserts the
claim with the confidence owed to a measurement, and no reader can see the join. so the word
names the join itself — the place where a sentence and its number diverge.

## .the property that makes it worth a word

a proxy holds only under conditions its author assumed and did not record. those conditions fail
in exactly the cases worth a diagnostic:

- duration substitutes for progress — until a human is attached, and duration means engagement
- a line count substitutes for elapsed time — until the cadence breaks, which is the emergency
- a sort order substitutes for the axis of advice — until two hands choose them separately
- ppid substitutes for agency — until the parent dies and init inherits
- a token found **anywhere in a file** substitutes for a value **in a list** — until that token
  also appears in a comment or an unrelated `require`, and then every file matches

each holds in the calm case and inverts in the urgent one. a proxy is therefore most wrong
precisely when it matters most, which is why the concept needs a name a reviewer can invoke.

## ⚠️ .a proxy survives the comment that warns against it

the last instance above is the one this term must be read against, because of **where** it was
found. `nvim.diagnose.watchdog` tests whether a config fix is live with:

```sh
grep -q "'neominimap'" "$LIVE_CFG"
```

and the comment directly above that line reads:

> *a stale fix string is the `proxy` shape: a claim substituted for a measurement
> (rule.require.name-what-you-measured)*

the token appears many times in that file — a `pcall(require, ...)`, a cache guard, prose. so the
test matched, the report said **"the fix IS in the live config"**, and the exclusion it claimed to
find was absent. the leak was live while the tool called it delivered.

> **the author named the hazard, then built the check out of it.** a proxy is not defeated by
> knowledge of proxies. it is defeated only by a test whose subject is the claimed value —
> here, the `exclude_filetypes` list, never the file that contains it.

this is why `rule.require.name-what-you-measured` demands the measured value be **printed**. a
report that had said *"exclude_filetypes = { neo-tree, oil, help, lazy, codediff-explorer }"*
would have been read as wrong at a glance. one that says *"the fix IS in the live config"* cannot
be checked by the human it misleads.

## .refs

**the rule it grounds:**

- `.agent/repo=.this/role=any/briefs/rule.require.name-what-you-measured.md`

**the eight recorded instances** — see the reason file for the table; each is a shipped defect
in this repo's own diagnostics, across `machine.usage.diagnose`, `machine.diagnose.churn`,
`machine.diagnose.class`, and `nvim.diagnose.watchdog`.

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **proxy** | one value substituted for another, by an authority that can be checked | ✅ names the substitution AND its accountability |
| `heuristic` | a rule of thumb, accepted as imprecise | ✗ excuses the gap; a proxy's gap is a defect to state |
| `approximation` | numerically near the truth | ✗ a proxy is often exact, and about the wrong quantity |
| `stand-in` | a temporary substitute | ✗ a proxy is permanent, and that is the hazard |
| `signal` | correlates with the truth | ✗ too weak — a proxy is *presented as* the truth |
| `indicator` | points toward | ✗ names the direction, not the substitution |

`approximation` draws the sharpest line: line-count-times-30s is not a *near* measure of elapsed
time. it is an exact measure of a different quantity. the error is categorical, not numeric —
which is why no tolerance can fix it and only an explicit statement can.

## .reason

see the ref-level file beside this choice:

- `term=proxy._.choice.reason.md` — etymology, the eight instances, and why the pattern was
  promoted from a lesson to a rule
