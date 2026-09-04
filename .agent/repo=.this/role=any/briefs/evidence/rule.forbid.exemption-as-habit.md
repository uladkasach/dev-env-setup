# rule.forbid.exemption-as-habit

## 🛑 .the rule, in one line

# **AN EXEMPTION YOU REACH FOR EVERY TIME IS AN ABSENT FEATURE. BUILD THE FEATURE.**

the third time you type the same exemption for the same reason, stop. the tool
is short a capability, and each use of the exemption is a vote to leave it short.
**upgrade the tool.**

> ⚠️ *escape hatch* is the human's word and stays welcome in prose. the TERM is
> `exemption`, which the guards and the neighbouring rules already speak
> (`term=exemption`).

## .why

this repo already forbids the workaround (`rule.require.solve-at-cause`) and already
demands that an exemption name its trigger (`rule.require.exemptions-name-their-trigger`).
neither catches this shape, because the hatch here is **legitimate**:

- it is a real, documented flag
- its trigger is real, and it fires
- each individual use is correct

so no check goes red. the defect is not in any one call — it is in the **frequency**,
and frequency is a fact no single call site can see.

⚠️ and the cost compounds in a direction that hides itself:

1. the hatch works, so the gap never surfaces as a failure
2. its use spreads into briefs, plays, and howtos as the demonstrated form
3. new readers learn the hatch as the normal way, not as the exemption
4. the tool's real default is now the thing nobody uses

by step 4 the exemption IS the interface, and the documented default is dead prose.

## .the test

> **how many times have I typed this exemption, and was the reason the same each time?**

| answer | verdict |
|---|---|
| once or twice, different reasons | fine — that is what an exemption is for |
| every time, same reason | 🛑 the tool is short a feature. build it |
| I cannot say | count them. `grep` the repo for the flag |

the sharper form, for the moment you are about to type it:

> **am I about to leave the paved road because the road is wrong for this trip, or
> because the road cannot do a thing it obviously should?**

the first is an exemption. the second is a backlog item you have been paying interest
on, one keystroke at a time.

## .measured — `--bare`, 2026-08-13

`git.grove.send` returns the exit code of the SEND, never the remote command's — a duct is
tmux, so a send is a keystroke. every verify had to leave the duct through `--bare`, with a
`--why` that recited the identical sentence dozens of times in one session, every use correct.
the human read it once: *"can't you upgrade the duct to `--await`? you should just upgrade
your tools, not use escape hatches."*

⇒ the answer was `--reply`: the duct now waits for the command to finish and returns its own
stdout and exit code. the trigger that fired dozens of times cannot fire again.

⚠️ the tell was in the `--why` text itself: identical justification on every use is not
justified per-call — it is a fixed condition, and a fixed condition is a requirement nobody
wrote down. full write-up: `.refs = rule.forbid.exemption-as-habit.demo=bare-flag, m1`.

## .why the guard did not catch it

`rule.require.exemptions-name-their-trigger` made `--why` mandatory precisely so the
caller would re-check the trigger each time. that worked: the trigger was re-checked,
and it fired every time regardless.

**a guard that asks "does the trigger fire?" cannot detect "this trigger always
fires."** the first is about one call; the second is about the distribution. so this
rule asks the question the per-call guard structurally cannot.

⇒ when you add a `--why`-style guard, know that it catches habit-with-no-reason and
misses reason-that-never-stops. this rule is the other half.

## .what "upgrade the tool" means, concretely

it does not mean widen the hatch. it means give the default road the capability the
hatch was reached for:

| 👎 the hatch, widened | 👍 the road, extended |
|---|---|
| make `--why` optional after N uses | make the duct return the verdict |
| a wrapper that always passes `--bare` | `--reply`, so `--bare` is not wanted |
| a brief that documents the hatch as normal | a brief that documents the new default |

⚠️ and when the feature lands, **retire the trigger at the guard**. the `--bare`
help text now says the verify trigger is no longer a trigger and names `--reply` in
its place. a hatch whose reason is gone but whose docs still offer it will be typed
again by the next reader, on the authority of your own help text.

## .the one caveat — do not inflate

this rule fires on **repetition of the same reason**, not on discomfort. a flag you
dislike, or one used twice for two different reasons, is not this. and the upgrade
must serve the reason that recurred, not every reason it could imagine
(`rule.forbid.inflate-an-additive-ask`).

`--reply` is the shape to copy: it does one thing, it composes with the extant
`--await` rather than absorbing it, and it left the default cheap — a **drive** still
sends and returns, and only a **verify** pays for the wait.

## .enforcement

- the same exemption typed 3+ times for the SAME reason, with no move to build the
  capability = **blocker**
- an exemption's `--why` text that is identical across call sites = **blocker** (it is
  a standing condition, so it is a requirement, so it is owed a feature)
- a widened hatch shipped in place of the extended default = **blocker**
- a feature landed without retirement of the now-dead trigger in the guard's own help
  text = **blocker** (the docs will re-teach the hatch)
- a brief, play, or howto that demonstrates the hatch where the default now serves =
  **blocker**

## .see also

- `rule.forbid.exemption-as-habit.demo=bare-flag.md` — the `--bare` measurement in full
- `rule.require.solve-at-cause` — the general form; this is its exemption-shaped case
- `rule.require.exemptions-name-their-trigger` — the per-call guard this completes
- `rule.require.wrap-cli-in-skills` — the same instinct one level up: a retyped
  incantation is a skill nobody wrote yet
- `gotcha.the-duct-returns-the-send-not-the-answer` — the measurement behind `--reply`
- `rule.forbid.inflate-an-additive-ask` — the bound on how far the upgrade may reach
- `.agent/repo=.this/role=any/skills/git.grove.send.sh` — carries `--reply` and the
  retired trigger inline
