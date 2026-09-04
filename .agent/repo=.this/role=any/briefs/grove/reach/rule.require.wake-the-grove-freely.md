# rule.require.wake-the-grove-freely

## .what

`grove.wake` is a **standing authorization**. when a traveler needs a grove and the grove is
down, asleep, or its tunnel is dead — wake it. do not pause to ask permission first.

the human, 2026-07-28:

> dude you should always feel free to wake your grove

## .why

### the operation is designed to be reversed

`grove.wake` and `grove.stop` are a matched pair. a wake starts a box that a `grove.stop --how
hibernate` puts straight back. that is the whole point of the pair — the grove is meant to spend
most of its life asleep and be woken on demand. an operation with a one-command inverse is not
the kind that warrants a confirmation.

it is also **idempotent**: a grove already up reports `[KEEP] already up` and changes no state.
the common case of a wake is that only the *tunnel* was dead, which costs zero.

### the cost is cents, the ask is minutes

the box is small and hibernates when idle. an unneeded wake costs a trivial amount of money. an
unneeded question costs the human a context switch — the scarcest resource in the loop. to trade
the second for the first is a bad trade every time.

### a duct is the verification surface, so a stalled wake stalls the proof

`term=duct` records that a duct is **the declared way this repo reaches a machine**, and the
surface work is verified on — not a fallback for when a local tool is denied. many local checks
are denied by permission hooks by design, which means the duct is often the *only* path to a
real answer.

a traveler who hesitates at the wake does not merely delay a box — they delay the
verification, and the usual next move is to claim a result they never proved. **the
hesitation is the defect, not the wake.**

## .the rule

| the grove is... | you must... |
|-----------------|-------------|
| asleep, and you need it | wake it — no ask |
| already up | the wake is a no-op; run it anyway to repair the tunnel |
| awake but unreachable | wake it — the tunnel is the usual culprit |
| awake, and you are done | `grove.stop --how hibernate` when the work is done, not mid-task |

## .what the wake may ask of you first

a wake can fail on a credential, not on permission:

```
💥 cannot read the active aws account
  fix: rhx keyrack unlock --owner ehmpath --env camp
```

that unlock is also within the standing authorization — run it, then wake. only an unlock that
demands a **human touch** (a yubikey tap, an sso approval in a browser) is a genuine halt, and
even then you halt with the exact command, never with "the grove is down".

## .what is still NOT authorized

the standing authorization covers the wake, and only the wake:

- **`grove.stop --how halt`** — a halt is not a hibernate; it discards live state. ask
- **a new grove** — `git.grove.set` provisions a box that did not exist. ask
- **`git.grove.del`** — destroys a machine and its trees. ask
- **a wake of a grove you were not asked to work on** — the authorization follows the task

## .the test

> if I wake this and it turns out I did not need it, what is the cost?

- a few cents and one `grove.stop` → **wake it**
- lost work, a destroyed box, or a bill a human would notice → **ask**

## .enforcement

- a halt of the work to ask permission for a `grove.wake` = **nitpick** (spends the human's
  attention on a settled question)
- a claim reported as verified when the verification was skipped because the grove was asleep =
  **blocker** — this is the failure the rule exists to prevent
- an escalation that says "the grove is down" without an attempted wake = **blocker**

## .see also

- `domain.terms/term=duct._.choice.reason.md` — why a duct is the verification surface, not a
  fallback
- `domain.terms/term=grove.wake._.choice._.md` — what the wake drives (egress, box, duct, alias)
- `domain.terms/term=grove.stop._.choice._.md` — the inverse, and why `--how` picks the mode
- `rule.require.judge-declared-state-not-live-state` — a woken grove is where declared state gets
  proven
