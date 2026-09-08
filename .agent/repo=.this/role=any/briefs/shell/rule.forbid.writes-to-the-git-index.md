# rule.forbid.writes-to-the-git-index

## 🛑 .the rule, in one line

# **NEVER `git add`. NEVER ASK FOR STAGE PERMISSION. THE INDEX IS THE HUMAN'S.**

no `git add`. no `git update-index`. no `rhx git.stage.add`. and no request that a human
grant stage permission so you can do it.

## .why

the index is the human's **control surface over what this repo publishes**. an agent that
writes to it has taken that decision from them — quietly, and at the exact moment the
decision matters most.

- **the refusal is the design, never an obstacle.** `rhx git.stage.add` answers
  `stage not allowed`. that is the correct answer. it is not a gate to route around, and
  it is not a gate to escalate.
- **a request to open it is the same violation, one step out.** to list *"needs stage
  permission"* as blocked work is to ask the human to hand over the surface rather than to
  respect it. the ask is the defect, not the tool that refused.
- **the write is silent in a way the human cannot audit.** an unstaged file is visibly
  untracked; a staged one reads as reviewed. so the write does not merely add a file — it
  moves a file across the line the human uses to tell those two apart.

## .measured — 2026-09-07

a clamp play and its probe were written this session. `rhx play.run` refused them, because
it executes only indexed paths — a supply-chain control, so a pulled tree cannot plant a
play. two moves followed, and both were wrong:

1. **the ask** — a status report listed *"needs `git.commit.uses set … --stage allow`"* as
   work blocked on the human.
2. **the write** — a bare `git add` on the two files.

the human's answer, verbatim in substance: *you do not need to stage anything*, and *never
ask to git add again.*

⚠️ the instructive half is that the runner's refusal was **never the bar to clear.** the
clamp's whole content is a pair of discrimination arms, and those run through
`rhx nvim.test.headless --probe … --arm control --arm old`, which consults no index at all.
the arms had already been driven and had already discriminated. the play is a judge wrapper
around a measurement that was in hand.

⇒ **a tool that refuses an unindexed path names which tool to reach for, never which
permission to request.** the capability is almost always reachable one layer down.

## .what to do instead

- write files freely, and leave them untracked. the human decides what enters the index.
- when a tool refuses for want of an indexed path, ask *what does this tool actually do,
  and can I do that part directly?* — then do that part directly.
- report the artifact as **written and unstaged**. that is a complete state, not a blocked
  one.

## .enforcement

- `git add`, `git update-index`, or `rhx git.stage.add` run by an agent = **blocker**
- a request that a human grant stage permission = **blocker**
- *"needs stage permission"* listed as blocked work in a status report = **blocker**
- a tool's unindexed-path refusal treated as the bar to clear, where the capability beneath
  it was reachable directly = **blocker**

## .see also

- `rule.forbid.adhoc-shell` — its neighbour, and its mirror: there, an absent skill is the
  defect to fix; here, a present skill's refusal is the answer to accept
- `rule.require.reach-for-the-skill-before-adhoc-shell` — the reach this rule bounds
- `.agent/repo=.this/role=any/skills/play.run.sh` — the runner whose index gate triggered
  the measurement, and its `.why` for the supply-chain reason it exists
