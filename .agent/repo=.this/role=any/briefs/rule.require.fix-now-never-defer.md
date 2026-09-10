# rule.require.fix-now-never-defer

## .what

when you find a defect while you work, **fix it in that same turn**. do not merely describe it,
do not propose it, do not close the turn with "want me to fix X first, or do Y?" — fix it,
verify it, then report what was fixed.

## .why

a defect written up but not fixed costs a full round trip and leaves the system broken. the
human already asked for the outcome; a menu of options is a request they must answer before
anything improves.

the origin: a machine-slowness diagnosis found two broken `/proc` skills
(`machine.attribute.memory`, `nvim.inspect.embed`), described the defect precisely, offered a
fix, and ended with *"want me to start with the skill fix, or take the immediate relief?"* —
then did neither. the next human turn was *"did you fix those /proc skills too?"*, followed by
**"fix everything always and never defer this again."**

worse, the unfixed skills were exactly the tools needed to finish the diagnosis. the deferral
did not just delay a repair — it blocked the investigation that motivated it. once fixed, they
immediately revealed the true root cause (191 leaked keyrack daemons), which the process-level
guess had missed.

## .the boundary — this is not a license to be reckless

the ask-first default still holds for **risky, hard-to-reverse, shared-state** actions:

| just fix it | ask first |
|-------------|-----------|
| a broken skill or executable in this repo | force push, branch delete, `reset --hard` |
| a local file, config, or comment | anything that messages or notifies other people |
| a repo-paved cleanup skill whose plan mode you ran first | destroying uncommitted human work |
| a lint or convention violation you just walked past | modifying CI/CD or shared infrastructure |

the test: **is it local, reversible, and within the work the human already asked for?** if yes,
fix it now. if it reaches beyond this machine or destroys work, ask.

## .how

1. found a defect mid-task → fix it in this turn
2. several independent defects → fix **all** of them; the answer to "which first?" is "both"
3. verify each fix actually works (run the thing, do not assume)
4. report what was fixed — "fix everything" is not "act silently"
5. a destructive step with a plan mode → run plan, read it, then apply

## .the anti-pattern

a turn that ends with a question whose every branch is something you could have just done.

```
👎 "i found two broken skills. want me to fix them, or take the immediate relief first?"
👍 "fixed both skills (verified), then ran the prune. here is what they revealed: ..."
```

## .enforcement

- a defect found and described but not fixed in the same turn = **blocker**
- a turn that closes with a menu of self-executable options = **blocker**
- a fix applied but never verified = **blocker** (see `rule.require.clamp-edge-cases`)

## .see also

- `rule.require.solve-at-cause` — fix the cause, not the symptom; this rule sets *when*
- `rule.require.clamp-edge-cases` — a fix must be proven, not assumed
- `rule.require.install-via-procedures` — how to fix env defects durably, not one-off
