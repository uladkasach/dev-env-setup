# rule.forbid.inflate-an-additive-ask

## .what

when the human asks to **make a capability possible**, scope it as an **option added
beside** the extant path. never reframe it as a replacement, a swap, or an undecided fork
that halts the work.

"make it possible to X" ≠ "replace Y with X".

## .why

a swap framework manufactures a decision the human never asked for. it converts a cheap,
additive change into a fake architectural fork — and then blocks on it.

### measurement — the mosh dream, 2026-07-31

the human asked to catch a dream for **mosh** (mobile shell), so a person could reach a
grove over a link that tolerates jitter. the ask was one sentence: *make it possible to mosh
for humans*.

the dream came back written as *"swap the transport under the duct"*, with a three-way fork
marked **undecided** and gated behind "do not install until it is settled":

1. keep ssm, drop mosh
2. direct udp path
3. hybrid

the human's correction: *"i didnt say rip out ssh did i? i just said make it possible to
mosh for humans."*

the real shape was far smaller — a `2.shell` bundle that installs mosh on both ends, and
**zero** changes to any skill, because `git.grove.*` keeps its ssh transport untouched. the
fork existed only because the ask had been misread as a replacement.

## .the constraint is a prerequisite, not a fork

the udp fact was correct and worth a keep: mosh needs udp 60000–61000, and
`git.grove.wake` reaches a grove through an **ssm port-forward** — a tcp tunnel mosh cannot
ride.

but that is a **prerequisite for the new door**, not a question about the old one. framed
as a prerequisite, it reads:

> the mosh door opens only where a direct udp path exists. if the answer is "no udp", none
> of it regresses — the ssh path was never in play.

state the no-regression line explicitly. it is what stops a prerequisite from being read as
a blocker.

## .how

when the ask is additive:

1. name the new option as a **door**, and say plainly the extant door is untouched
2. keep every call site unchanged — if the new option needs skills edited, re-check whether
   you have widened the ask
3. put real-world constraints under `.prerequisite`, never under a fork or a decision
4. add the line that names what regresses if the prerequisite is unmet (usually: none)

## .enforcement

- an additive ask written as a swap/replacement = **blocker**
- a fork or "undecided decision" raised where the human asked only for an added option =
  **blocker**
- a prerequisite framed as a blocker, with no note of what regresses if unmet = **nitpick**

## .see also

- `rule.avoid.narrate-obvious-choices.md` — the adjacent restraint on unasked-for framework
- `.dream/2026_07_31.mosh-over-ssh-for-grove-ducts.dream.md` — the dream this rule was cut from
