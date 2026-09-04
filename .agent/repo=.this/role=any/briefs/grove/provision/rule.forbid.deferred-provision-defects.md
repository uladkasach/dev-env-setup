# rule.forbid.deferred-provision-defects

## 🛑 .the rule, in one line

# **A DEFECT AGAINST `rule.require.one-command-provision` IS FIXED NOW. IT IS NEVER FILED.**

no task. no backlog entry. no "worth a follow-up". no "flagged for later". no ⚠️ note in a
brief that stands in for the work. **zero deferrals, zero exceptions.**

the moment you find that a grove needs a hand step, a second apply, a prompt answered, or an
env var exported — that is the work. it is not a discovery to record and move past.

## .why a task is WORSE than silence here

a filed task feels like diligence. it is the opposite, and the reason is precise:

1. **it converts a blocker into an item.** `rule.require.one-command-provision` says *blocker*.
   a task says *unresolved*. the same fact, restated in a register that carries no gate.
2. **it discharges the obligation without the work.** once written down, the defect is
   "handled" — so the session moves on, and the next session inherits an entry rather than a
   symptom.
3. **it makes the bar read as an aspiration.** a rule with four open tasks against it is not a
   rule anyone treats as binding. the backlog IS the exception list, written one row at a time.
4. **the box still works.** that is the trap. the human massages it through, the smoketest goes
   green, and the *procedure* that produced the box is unrecorded and unrepeatable.

## .measured — 2026-08-12, four in one provision

a fresh grove was provisioned. it needed four hand steps and three applies. every one was
**filed instead of fixed**:

| # | the defect | what was done | what was owed |
|---|---|---|---|
| 73 | camper's login-shell record is never converged, so every transport gets a bare PATH | filed; the wrong *comment* corrected | fix the bundle |
| 75 | the bootstrap push sends `src/` only; `--into` nests a single file | filed | fix the push |
| 77 | a verify measures process state its own run just changed — 7 claims, 1 cause | filed | fix the verify |
| 78 | a test-ready grove carries no `ACCESS` | filed; a workaround written INTO the smoketest | fix the owner |

⚠️ #73 is the sharpest. the wrong *reason* inside its decline was corrected with care — a
whole ⚠️ block, a term file updated, a measurement recorded — and the **defect itself was left
in place**. to correct the explanation of a bug and file the bug is the exact shape this rule
forbids: the effort goes into the record, and the box still needs a human.

⚠️ #78 is the second-sharpest, and it is worse in one way: the workaround was written into
`git.grove.provision test` itself, with a task number in the comment. the gate now carries the defect
it exists to catch, and the comment makes that look deliberate rather than owed.

## .what "fix it now" means when the fix is genuinely large

it means **fix it now**, and the size is not an exit. three honest moves, in order:

1. **fix the bundle.** almost always available, almost always smaller than it looks.
2. **fix the seam.** where the defect is that one seat cannot grant itself a power, the fix is
   a bundle on the seat that CAN (`rule.require.seam-claims-have-an-owner`).
3. **halt and say so.** if the fix genuinely cannot be made now — it needs a fresh grove, or a
   decision only the human can make — **stop and say that**, in the conversation, as a blocker.

what is forbidden is the fourth move: write it down, call it tracked, and continue.

⚠️ a halt is not a deferral. a halt stops the work and names what unblocks it. a deferral
continues the work with the defect unowned. the difference is whether the session still moves.

## .the ONE cause worth a halt

the fresh grove. a change to `src/grove.provision/**` must be proven on a grove built from
scratch (`rule.require.one-command-provision`), and one cannot always be summoned. so:

> **the only legitimate halt is to ask the human to have `ahbode/infrastructure` provision a
> fresh grove to test against.**

every other blocker is fixed in the repo, now. a halt for any other reason is a deferral with
better manners.

## .the test

before you write a task, an entry, or a ⚠️ note about a provision defect:

> **would this box have needed a human, if I stopped here?**

- yes → then this is the work. do it.
- no → then it was already fixed, and the note is a record rather than a substitute

and its sharper form, for the case that actually recurs:

> **am I about to write down WHY a defect happens, instead of removing that it happens?**

an explanation is owed *in addition to* the fix, never instead of it.

## .enforcement

- a task, issue, or backlog entry filed for a defect against
  `rule.require.one-command-provision` = **blocker**
- a ⚠️ note, comment, or brief section that records a provision defect without a fix =
  **blocker**
- a workaround written into a tool, with a task number cited as its justification = **blocker**
  (the citation makes the debt look owned; it is not)
- a correction to a defect's *explanation* shipped without a correction to the *defect* =
  **blocker**
- "this is out of scope for now" applied to a provision defect = **blocker**; there is no scope
  in which a grove may need a human
- a halt for any cause other than *"I need a fresh grove"* = **blocker**

## .see also

- `rule.require.one-command-provision` — the bar this protects
- `rule.forbid.repair-plays` — the same instinct at the artifact level: a repair play IS a
  deferral, made executable
- `rule.require.fix-forward` — fix forward, and this says *now*
- `rule.require.seam-claims-have-an-owner` — where the "one seat cannot grant itself" fix goes
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the adjacent decay: a rule with a long
  backlog against it stops being read as a rule
