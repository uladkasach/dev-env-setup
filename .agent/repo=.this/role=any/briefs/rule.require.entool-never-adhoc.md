# rule.require.entool-never-adhoc

## .what

every investigative or diagnostic move must be **entooled** — written as a skill under
`.agent/repo=.this/role=any/skills/` and invoked as `rhx <name>` — never run as a one-off shell
probe.

## .why

an ad-hoc probe is knowledge that evaporates. the next traveler re-derives the same `/proc` reads
by hand, and a human at a prompt cannot reuse a command that lived only in one agent's transcript.
a skill serves both, and it accumulates every correction earned since.

the evidence is this repo's own history: the machine-slowness rounds re-derived the same census,
the same psi read, and the same fork-rate math three separate times before they were entooled.
each re-derivation reintroduced defects the prior round had already fixed.

there is a second, sharper reason. a skill is **reviewable**. an ad-hoc pipeline is judged once,
in flight, under time pressure. a skill is read, corrected, and re-corrected — which is how
`wedged` gained its tty clause, how the census stopped its abort under load, and how the watchdog
rate stopped its trust in a cadence.

## .when the reflex is strongest — and most wrong

mid-diagnosis, with the machine on fire, the pull toward "just one quick `ps`" is at its peak.
that is exactly the moment the rule matters: a diagnosis run under load is the one most likely to
recur, so it is the one most worth a durable home.

## .how

| the situation | the move |
|---------------|----------|
| a question needs more than one `Read` / `Grep` | write a skill, then run it |
| an extant skill nearly fits | add a flag to it — do not probe around it |
| a truly one-shot read of one file | `Read` is fine; that is not a probe |

when an extant skill nearly fits, extend it. a probe written "just this once" beside a skill that
almost answers the question is the worst outcome: the skill stays wrong, and the correction lives
in a transcript.

## .examples

### 👎 bad — the probe

```sh
ps -eo pid=,rss=,comm= | awk '$3 ~ /nvim/ {sum += $2} END {print sum/1024}'
```

answers the question once. teaches no one. cannot be re-run by a human, and the next agent writes
a slightly different, slightly wrong version of it.

### 👍 good — the skill

```sh
rhx machine.diagnose.class --of nvim
```

same answer, plus: a `--drill` for one member, the leak-vs-headcount correlation, and the
cheapest/median/dearest spread that a prior round proved was needed.

## .the test

ask: "if this question recurs in a month, does what i just wrote help at all?"

- yes → it is a skill
- no → entool it before you run it

## .enforcement

- a multi-step diagnostic run as an ad-hoc shell pipeline = **blocker**
- a probe written beside an extant skill that could have been extended = **blocker**

## .see also

- `rule.require.install-via-procedures` — the same discipline, for installs
- `rule.require.repo-as-source-of-truth` — the same discipline, for config
- `howto.diagnose-machine-slowness` — the entooled path this rule produced
