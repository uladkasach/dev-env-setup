# rule.prefer.deterministic-signal-over-timer

## .what

when a feature must know *"is this state still live?"*, key it on a **real observable**, never
on a wall-clock timer.

a timer is a PROXY for the question. reach for one only after you have measured that no signal
answers it — and then name the residual ambiguity in prose rather than pretend the timer closed
it.

## .why — a proxy gets it wrong in BOTH directions

that is the shape, and it is why a timer is worse than it looks. it does not merely lose
precision; it produces two OPPOSITE faults from one value, and no single number fixes both:

| the fault | what a human sees |
|---|---|
| the window is too LONG | a state that should have ended is still live |
| the window is too SHORT | a state that is genuinely live gets killed |

⇒ so a timer tuned away from one fault is tuned INTO the other. there is no correct value, only
a preferred failure.

## 📜 .measured 2026-09-06 — the nvim diff-boundary repeat

`<C-d><C-j>` armed a repeat, and a `1500ms` idle timeout ended it. the timeout was a proxy for
*"did the ctrl hold end?"*. it got both directions wrong on the same box, in the same minute:

| fed | the timer did | the truth |
|---|---|---|
| arm, then a stray `w`, then `<C-j>` | **jumped** — the arm was still live | `w` needs ctrl UP; the hold was over |
| arm, pause 2500ms, then `<C-j>` | **scrolled** — the arm was killed | the hold never ended; the human just paused |

the deterministic replacement is a **declared key set**: any key outside
`{<C-d> <C-j> <C-k> <S-CR>}` disarms. both rows above now behave correctly, and the clamp for
the first was proven to bite (neuter the walk → `delta 11` becomes `delta 2`).

## 📜 .measured 2026-09-06 (ii) — the same proxy, in a PROBE rather than a feature

the second instance, and it is worth its own entry because the subject is different in a way
that matters: here the timer sits in the **measurement apparatus**, not in a shipped behavior.

a discrimination probe for the nvim breaker deferred its body `1500ms` to let lazy.nvim finish
plugin load, then `require`d a plugin module. the question the timer stood in for:

> *"are the plugins loaded yet?"* — never *"has 1500ms passed?"*

⇒ the direct signal exists and is one line. verified in the vendored source rather than assumed:

```
lazy/init.lua:115   nvim_exec_autocmds("User", { pattern = "LazyDone", modeline = false })
```

⚠️ **the fault a probe's timer produces is worse than a feature's**, and that is the lesson this
instance adds. both directions still apply, but the SHORT direction no longer reports a defect —
it reports a **verdict about the wrong world**: the `require` fails, the arm reports whatever a
half-loaded editor does, and the row reads as a fact about the subject
(`gotcha.a-check-that-cries-wolf-gets-silenced`, q5 — *did the fixture this probe built actually
take?*).

⇒ so a probe that waits on a clock owes a read-back that its world exists, or it owes the signal.
this one had neither, and it went green — which is the tell that it proved less than it claimed.

## .how to apply

1. **name the question** the timer stands in for. *"did the hold end?"*, never *"has 1500ms passed?"*
2. **hunt the direct signal**, and measure whether it is reachable END TO END — every hop, not
   the first one you doubt
3. **if the direct signal is unreachable, hunt an EQUIVALENT one.** this is the step most often
   skipped, and it is where the win usually is
4. **only then** may a timer stand, and it owes the ambiguity it cannot settle, in prose

### ⚠️ step 3 is the one that pays — the equivalence is often free

the diff-boundary case wanted a ctrl RELEASE, which nvim drops. but:

> a hold cannot continue THROUGH an off-vocabulary key. `w` requires ctrl to be up.

so *"ctrl is still down"* and *"every key since the arm was ctrl-modified"* are the **same
claim**, and the second is reachable from press events alone. the lift is INFERRED from what it
makes possible.

⇒ **when the direct signal is absent, ask what the event you cannot see would ENABLE.** that
consequence is often observable when the event is not.

## 🛑 .measure every hop before you design against a route

the corollary, and it cost a wrong repair plan before a measurement caught it.

the release was assumed unreachable *because tmux swallows it*. **false** — tmux relays every
release form byte for byte; NVIM drops them. had the assumption stood, the whole repair would
have aimed at tmux, where there was no defect at all.

⇒ a route is a chain, and a capability exists only where EVERY hop carries it. so a claim about
"the route" that names one hop untested is a guess in a measurement's clothes
(`rule.require.trust-but-verify`). `howdoes.a-key-event-reaches-nvim` is the worked example: 11
rows, one per hop per direction.

## .when a timer IS correct

this rule prefers, it does not forbid. a timer is the right tool when the thing measured **is**
a duration:

- a **timeout on a remote call** — the question genuinely is "has too long passed?"
- a **debounce** whose contract is stated in time (an autosave, a redraw budget)
- a **rate limit**

the tell: can you state the requirement without a number? *"the repeat ends when the hold ends"*
needs no number, so a number is a proxy. *"a probe declines after 30s"* IS the number.

## .enforcement

- a timer used to answer a question that a signal could answer directly = **nitpick**
- a timer shipped with no record of which direct signal was sought and why it was unreachable =
  **nitpick**
- a claim that a signal is unreachable, with any hop on its route unmeasured = **blocker**
  (`rule.require.trust-but-verify`)
- a timer whose residual ambiguity is left unnamed in prose = **blocker**; it reads as a closed
  case and is an open one
- a **probe** that waits on a clock for its world to exist, with neither the signal nor a
  read-back that the world took = **blocker**; its short-direction fault is a verdict about a
  world nobody built, and it goes GREEN

## .see also

- `howdoes.a-key-event-reaches-nvim` — the 11-row hop matrix, and the two walls it found
- `inventory.of=behaviors.via=nvim.case=diff-boundary-nav` — the behavior this reshaped, with
  the matched pair of rows the timer got wrong
- `rule.require.trust-but-verify` — why an unmeasured hop is a guess
- `rule.require.clamp-edge-cases` — the bite proof the replacement owed
- `term=arm._.choice._.md` — the term this corrected; a word chosen for a MECHANISM went stale
  the hour that mechanism was retired
