# rule.always.provision-only-the-grove-you-were-asked-for

## 🛑 .the rule, in one line

# **A PROTECTED GROVE IS PROVISIONED ONLY WHERE A HUMAN ASKED. AN UNPROTECTED ONE IS WHAT YOU TEST AGAINST.**

no wake, no push, no apply, no gate, no stop, no registry write against a **protected** grove the
human did not name. a box you found in a list is not a box you were asked for.

## .the two kinds, and why both must exist

| kind | holds | so |
|---|---|---|
| **protected** | a human's live work | provisioned ONLY where they ask for it by name |
| **unprotected** | a disposable target | this is what you test against — and without one, a change to the bundle tree cannot be proven at all |

⇒ the split is not a courtesy. `rule.require.one-command-provision` demands every change to
`src/grove.provision/**` be proven **on a grove built from scratch**, so an unprotected grove is
the instrument that rule requires. and it is the ONLY instrument: a protected box cannot serve,
because a first apply against live work is the act this rule forbids.

**settled 2026-09-28** — protected: `grove-ahbode-v20260901` (september). unprotected, and the
targets of that day's work: `grove-ahbode-v20260811` (august), `grove-aether-v20260921` (aether).

## .why this is a RULE and not a mechanism

the human's own words: *"thats just a rule."*

that refused a lock. a protect-list, a deny-glob, or a guard inside `git.grove.*` would each be a
**second holder of one fact** — which boxes are protected today — and that fact changes by the
hour. so the defect a mechanism buys is the one this repo keeps re-learning: a declared list goes
stale in silence, and then refuses the box the human just asked for.

⇒ the conduct is the control. it costs one question and never goes stale.

## 🛑 .why a DISCOVERY reads as an invitation, and is not one

the hazard is not disobedience. it is that a **survey** and an **assignment** produce the same
shape on screen:

```
🔭 aws.ec2.get --tag exid=grove-*
   └─ found: 2
      ├─ <instance-id>   stopped   grove-ahbode-v20260811     ← asked for
      ├─ <instance-id>   running   grove-ahbode-v20260901     ← PROTECTED
```

both rows are true, both are reachable, and both have an obvious next command. **a list of boxes
is a list of boxes** — no row in it says which of them anybody wants touched.

⚠️ and a **glob reaches further than an ask**. `--tag exid=grove-*` was typed to find one grove
and returned every grove in the account. a registry read does the same: `git.grove.list` names
four seats, and an ask that named one of them said none of the other three.

## 📜 .measured 2026-09-28

a session was told *"provision august and ahction"* and, minutes later, *"only ahbode september
needs protected."*

between those two sentences an `aws.ec2.get --tag 'exid=grove-*'` had already listed september —
**running, since 2026-09-03**, unregistered in `~/.git.forest`. a single wake against that
instance id would have put a duct on a box holding three weeks of live work.

⇒ the ask that saved it was the human's, not a check's. **no row in that output looked different
from the row beside it.**

## .the test

before any verb that touches a box:

> **which sentence named THIS grove?**

- you can quote it → it is a target
- you found it in a list, a registry, or a glob → 🛑 **it is not.** ask, or leave it

⚠️ *"it was in the same account"* is not a sentence. nor is *"it sat beside the one I was asked
for"*, nor *"it looked idle"*.

## ⚠️ .what this does NOT restrict

- **a READ is free** — `aws.ec2.get`, `git.grove.list`, a plan against a named grove. discovery
  is how you find the box you were asked for, and this rule governs the WRITE that follows
- **an unprotected grove is a standing target** — that is its whole purpose, and a change to the
  bundle tree is owed a run against one
- **a grove named once is named for that work** — an ask does not expire mid-task; you need not
  re-ask between the push and the apply
- **the laptop is a grove and is always a target** — `rhx grove.provision` against this machine
  is the human's own box, run by the human's own hand

## .enforcement

- a wake, push, apply, gate, stop, or registry write against a **protected** grove no sentence
  named = **blocker**
- a glob or registry read treated as an assignment = **blocker**
- a PROTECT-LIST, deny-glob, or in-verb guard written to enforce this = **blocker**; the human
  refused a mechanism, and a stale list refuses the box they just asked for
- a bundle-tree change proven against a PROTECTED grove = **blocker**; that is what an
  unprotected one is for
- *"it was in the same account"* offered as the ask = **blocker**

## .see also

- `rule.require.one-command-provision` — what a provision must achieve once a grove IS a target,
  and why an unprotected grove is the instrument it requires
- `rule.require.prove-changes-on-a-grove` — the run that needs an unprotected box
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why a stale protect-list is the worse defect
- `term=grove._.choice._.md` — a grove spans both kinds, so this covers the laptop too
