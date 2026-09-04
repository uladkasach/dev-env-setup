# domain.term: swallow

term.chosen   = swallow
term.kind     = verb
term.synonyms.forbidden:
- eat         (the COMPLEMENT, not a synonym — a receiver, not the channel. see below)
- lose        (says it went nowhere; a swallow has a definite consumer, and naming it is the repair)
- discard     (reads deliberate; the whole cost is that no one chose this)
- drop        (a drop is noticed at the far end — a swallow is not, since no byte arrives to be missed)
- hide        (that is `failhide`'s word, and it names the RESULT; swallow names the mechanism)
- suppress    (implies intent and a policy; `2>/dev/null` has intent, a `$( )` has none)
- ignore      (the reader ignores; a swallow means the reader never got the chance)

## .what

a signal is **swallowed** when an intermediary on its way OUT consumes it, so the
reader it was addressed to never learns it existed.

the consumer is the **channel** — a redirect, a `$( )`, an arg-parse arm, a pipe,
a pane. never the destination.

## .the pair — swallow is OUTBOUND, `eat` is INBOUND

one channel, two directions, two words. the repo drew this line itself:

> a run has a tty on stdin (a duct pane is a tty), but its stdout is often a pipe…
> so the question is **swallowed on the way out** while the read still waits on the
> way in
> — `rule.require.grove-provision-as-the-only-entrypoint.md:131`

| word | who consumes | what is consumed |
|---|---|---|
| **swallow** | the CHANNEL, in transit | a signal leaving the subject |
| **eat** | a waiting RECEIVER | a message addressed to someone else |

⇒ so a prompt on a duct does BOTH, in opposite directions, and that is exactly why
it takes two words to say (`term=eat`).

## .why it costs

a swallowed signal leaves a residue **indistinguishable from a legitimate value**:

| swallowed | the residue reads as |
|---|---|
| a stderr, by `2>/dev/null` | "" — i.e. *no credential*, rather than *the call never ran* |
| an exit code, by `$( )` | 0 — i.e. *it worked* |
| a flag, by a `*) shift ;;` arm | the default — i.e. *you asked for the default* |

that is `rule.forbid.failhide`'s mechanism, named. the rule forbids the outcome;
this word names what produced it.

## .refs
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.grove-provision-as-the-only-entrypoint.md:131  # the pair, in one sentence
- .agent/repo=.this/role=any/skills/shell.syntax.verify.sh:68 # `--paths` swallowed in silence
- .agent/repo=.this/role=any/skills/git.grove.operations.sh:102   # every caller swallowed it with a redirect
- .agent/repo=.this/role=any/skills/nvim.test.headless.sh:123 # "a swallowed non-zero exit would hide a real nvim failure"
- .agent/repo=.this/role=any/skills/git.grove.push.sh:575     # a real rsync failure is NOT swallowed into a retry
- .agent/repo=.this/role=any/briefs/evidence/rule.require.exemptions-name-their-trigger.md:125

## ✔ .the five rack-read sites — REPAIRED 2026-08-25

📜 five sites each held a `2>/dev/null` over a rack read. all five carry the repair this term
prescribes: **change the carrier**, never add a receiver.

| site | shape |
|---|---|
| `git.grove.wake.sh:159` | halt |
| `git.grove.stop.sh:159` | halt |
| `aws.ec2.get.sh:86` | halt |
| `aws.whoami.sh:60` | halt |
| `git.grove.trust.gen.sh:349` | **tolerant** — still tolerant, no longer silent |

### the measurement that settled the repair

the rack has three states, and its exit code separates only ONE of them:

| state | stdout | stderr | rc |
|---|---|---|---|
| present | the value | — | 0 |
| locked 🔒 | empty | `status: locked 🔒` + an unlock tip | **2** |
| absent 🫧 | empty | `status: absent 🫧` + a set tip | **2** |

⇒ **both failures are rc=2.** so the swallowed stream was not merely helpful — it
was the ONLY discriminator. and the two states take OPPOSITE repairs, one of which
(`keyrack set`) has no entry-only mode and OVERWRITES a live value.

that is what makes this instance worse than the general case in `.why it costs`
above: the residue read not merely as a legitimate value, but as a legitimate value
**whose named fix destroys the credential the human was after**
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7 — a hurried reader applies the
plausible, specific, wrong fix).

### ⚠️ the sharpest instance, and what it teaches

`aws.whoami.sh` printed this, one line below the swallow:

```sh
PROFILE_USED=$(rhx keyrack get … --value 2>/dev/null || echo "")   # ← the word is destroyed here
…
echo "  if it reads 'absent', it was never filled —" >&2           # ← and a human is told to read it here
```

it told a human to read a stream it had deleted one line earlier. the author KNEW
the discriminator existed and named it in prose — and the channel had already
consumed it.

⇒ **a swallow is invisible to the person who writes its fix-text.** the two lines sat
eight apart, in one file, for months. so the tell is never in the message; it sits in
the CARRIER, one line above.

### 🛑 the repair that lost, and why

the first cut was a shared `keyrack.operations.sh` — a reader that classified the
state by a grep of the rack's stderr for `*locked*` / `*absent*`, plus a `keyrack_halt`
that re-wrote fix text per state.

**it fell before it shipped.** it re-implemented a classification the rack already
performs and re-wrote fix text the rack already emits — a second declaration of a
fact another component owns, coupled to that component's output FORMAT. that is the
invisible dependency `gotcha.a-check-that-cries-wolf-gets-silenced` m.2 records: it
appears in no import and no argument, and breaks in silence the day the phrasing
moves.

⇒ the rule-of-three (`rule.prefer.wet-over-dry`) argues for a shared reader at 5 sites
and says no word about whether the logic should exist at all. **ask first whether the
knowledge already lives upstream.** here it did, and the whole repair was to stop the
`2>/dev/null` (`rule.require.solve-at-cause`).

## .reason
see the ref-level cluster beside this choice:
- `term=swallow._.choice.reason.md` — the directional split, the two drift sites
  it settles, why `hide` names the wrong layer, and the first LIVE bite (a lapsed
  session reported as an absent credential, whose named repair is destructive)
