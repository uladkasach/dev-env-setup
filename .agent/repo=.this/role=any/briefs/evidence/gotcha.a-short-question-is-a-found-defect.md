# gotcha: a short question from the human is a defect they already found

## .what

when the human asks a brief, plain question about this repo — *"why is there an alias of
reboot and restart?"* — it is **a defect report**, not a request for an explanation.

answer it with a MEASUREMENT, then fix at cause. an explanation alone leaves the defect in
place and reads as though it were addressed.

## .why the shortness is the tell

the human does not ask about what is fine. a one-line question means they see an asymmetry,
a duplicate, or an unsupported claim — and the brevity is confidence, not casualness. they
are not curious; they are pointed.

⚠️ and the question is nearly always about a defect **every check here passed over**. that
is what makes it costly to answer as trivia: the defect survived the whole apparatus, so the
one signal that reached it is the sentence you are about to reply to.

## .the measurements

| the question | what it turned out to be |
|---|---|
| *"why is there an alias of reboot and restart?"* (2026-09-03) | `machine.reboot` and `power.restart` were one act under two words, and only one snapped the kitty window/pwd map. the repo's ONLY fix-text for a reboot recommended the lossy half |
| *"what is grove.rebuild?"* (2026-08-09) | a verb that matched no skill, cited across four artifacts — every reference authored by the robot (`gotcha.my-own-note-became-my-evidence`) |
| *"why wouldn't it just be via grove.provision?"* (2026-08-10) | a forbidden repair play, PLUS a transport change written to make the forbidden act convenient (`rule.forbid.repair-plays`) |

three questions, three defects, zero false alarms.

⚠️ the first is the one worth study, because the pair LOOKED like ordinary redundancy. two
aliases that both reboot is a shrug; two aliases where one silently discards your terminals
is a trap. **the answer to "why are there two?" is rarely "no reason" — it is usually
"because they differ in a way nobody wrote down."**

## .the shape of a right answer

1. **measure first** — grep the references and COUNT them. put the two definitions side by
   side. a count is what turns "they seem redundant" into "two references, and one is the
   fix-text that teaches the wrong half"
2. **name the defect plainly**, and name your own part in it where you have one
3. **fix at cause** — delete the second path rather than deprecate it
   (`rule.require.grove-provision-as-the-only-entrypoint`'s forwarder argument holds at any
   scale), and repair whatever TAUGHT it
4. **capture the judgment where a re-add happens** — an inline ban at the site the loser
   stood, plus a `domain.terms` cluster if a word was settled. the next author meets the
   comment before they meet the glossary

## 🛑 .what NOT to do

- **explain and stop.** the question was not a knowledge gap.
- **file it.** `rule.forbid.deferred-provision-defects` — a task restates a blocker as an
  unresolved, and the session then moves on with a clear conscience
- **deprecate the loser.** a deprecated alias still runs, so it is a live second path
- **record the reason and leave the defect.** to correct the EXPLANATION and keep the defect
  is the exact shape this repo forbids

## .the test

> **did my reply leave the box, or the repo, in a different state?**

- yes → it was treated as a defect report
- no → it was treated as trivia, and the human will have to ask twice

## .see also

- `gotcha.my-own-note-became-my-evidence` — the `grove.rebuild` measurement in full
- `rule.forbid.repair-plays` — the `grove.provision` measurement in full
- `term=power.restart._.choice.reason.md` — the reboot/restart judgment, with its dispute
- `rule.forbid.deferred-provision-defects` — why a task is worse than silence here
- `rule.require.solve-at-cause` — fix the cause, never the symptom
