# rule.require.fix-forward

## .what

when a defect surfaces, **fix it now**. do not file it as a task and move on.

a filed task is a defect that stays live on every box until somebody reads the backlog.

## .why

the human said it in three words — *"always fix forward"* — and first asked *"why didnt you
fix that?"* about a freshly filed defect. there was no good answer. **the reason to file had
felt sound in the moment, and it was not.**

## .measurement — the fix was already in my hands

`git.grove.send --play` sends `bash -l`, which on any box converged past `2.5.zsh` execs a
non-interactive zsh and loses `rhx` from PATH. every `rhx` line in every play exits 127.

I filed it as a task instead of fixing it — **in the same session in which I had already
built and proven the exact fix** (`_shell_at`, a per-seat `~/.zshrc` probe) for the identical
defect in `git.grove.ready.verify`.

so the cost of the fix was near zero, and the cost of the filing was that every play on
every converged grove kept reporting a false verdict.

⚠️ the tell: I had described the defect precisely enough to write a 40-line task about it.
**an accurate description of a defect is most of the diagnosis.** if you can write the task,
you can usually write the fix — and the task is the more expensive artifact, because it
must carry the context the fix would have made unnecessary.

## .the excuses that feel good and are not

| the thought | why it does not hold |
|---|---|
| "it is prior work, not mine" | it is live on every box either way. provenance is not a reason to leave it |
| "it is out of scope for this task" | a defect you tripped over IS in scope. you found it by walking the path |
| "I will lose my place" | you will lose more of it re-derived a week from now |
| "filing it is being organized" | a backlog is where defects go to be rediscovered by the next incident |

## .when a file IS correct

filing remains right when the fix genuinely needs the human's judgment:

- a **design fulcrum** whose rework would not be clean
- a **destructive or shared-state action** the human must authorize
- a **scope call** above this task's authority

and even then: say plainly *why* it is filed rather than fixed. do not let filing be the
default that silence chooses.

## ⚠️ .this does NOT license scope creep

fix the defect, not the surrounding code (`rule.forbid.inflate-an-additive-ask`). the bar is
the defect you actually tripped over — one repair, proven, then back to the task.

## .the shape of a forward fix

1. fix it at cause (`rule.require.solve-at-cause`)
2. prove it BOTH ways — red on the break, green on the repair
   (`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`)
3. record the measurement inline, so the next reader sees why the line is what it is
4. return to the task you were on

## .enforcement

- a defect described well enough to file, and filed rather than fixed = **blocker**
- a fix deferred because it was "prior work" or "out of scope" = **blocker**
- a legitimate file (fulcrum / destructive / scope) that does not NAME why it is filed =
  **nitpick**

## .see also

- `rule.require.solve-at-cause` — fix the cause, not the symptom
- `rule.forbid.inflate-an-additive-ask` — the boundary this rule must not cross
- `rule.require.prove-changes-on-a-grove` — a forward fix is unproven until it runs
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why a defect left live decays trust
