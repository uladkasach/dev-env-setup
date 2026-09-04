# domain.term.choice.reason: guarantee

## .etymology

from the ordinary sense — a promise that holds without anyone who checks it. that is exactly
the property this repo needed a word for: state a run sets ONCE so a later question cannot
arise, as against a check that watches for the question and reports when it comes.

the word was chosen over its near neighbours because each of those already names the act of
ASKING, and the whole point of this concept is that no one asks:

| rejected | what it actually names |
|---|---|
| `gate` | a decision made ON an answer — so it presupposes a question |
| `check` | the report of an answer |
| `precondition` | what must be true BEFORE a step, which is a gate's subject |
| `default` | a value used when none is given, and a caller may override one |
| `safeguard` | a fallback for when some other thing failed |

⇒ every one of those is about a question. a guarantee removes the question.

## .why it was itemized LATE, and what that cost

the concept had been load-bear in this repo for weeks before it had a word.
`rule.require.every-function-has-a-driver` stated the distinction plainly —

> a copy of a **guarantee** is worth more than a copy of a **check**, because a check that
> drifts **reports**, and a guarantee that drifts **hangs**

— and that sentence sat inside a rule about DRIVERS, where nobody who reasoned about apt
would find it. so the insight existed and was unreachable from the place it applied.

📜 2026-08-13. `grove.provision._.sh` held a hand copy of `PKG_APT_ENV` as its process-wide
braces. it had drifted to ONE of three members, and the absent `NEEDRESTART_MODE` is the one
whose absence once wedged a box for **57 minutes** behind a needrestart menu, with the dpkg
lock held and the duct eaten.

the drift was invisible by construction, and its own comment said why without notice of it:

> a per-call fix is a second list, and a second list drifts — this repo's most repeated defect

that comment was correct, and was written BY the second list that drifted.

⇒ so the cost of the late itemization is measurable: had the word existed, the rule
*"a guarantee is never hand-copied — it is expanded from its one declaration"* would have
been sayable in four words, and the copy would have read as wrong on sight.

## .the boundary against `gate`, which is the one that will recur

`sudo -n` is the hard case, and it is worth a note because it looks like a gate:

```sh
sudo -n chsh -s /usr/bin/zsh "$seat" || true            # a guarantee
pkg_can_sudo || { bundle.root.declines …; return 0; }   # a gate
```

both concern privilege. they differ in what they DO with it:

- `pkg_can_sudo` asks *"may I?"* and a branch turns on the answer → **gate**
- `sudo -n` asks no one. the `-n` makes a prompt unreachable, so the bad case cannot
  arise → **guarantee**

⚠️ and `pkg_assert_sudo` is BOTH, which is why it caused a false ✋ that condemned nine
correct sites (`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 6). read as a
gate it is a poor one — it fails the phase rather than declines. read as a guarantee it is a
sound one — it is `sudo -n true`, so no prompt is reachable below it. a citation about its
gate half was used to judge its guarantee half, and the check went red on correct code.

⇒ **the lesson the term now carries: name which half you mean.** an artifact can be a gate
under one question and a guarantee under another, and a verdict about one is not a verdict
about the other.

## .evidence

### the discovery — a dimensional walk over "what does its absence do?"

| remove the… | what a run does |
|---|---|
| check | prints one row fewer; every later step is unchanged |
| gate | runs work that should have been skipped; the box ends wrong, loudly |
| guarantee | **waits**, or silently permits; the run looks alive and emits no line |

the third column is a distinct cell, and it is the one with no vocabulary — which is what
told us a word was owed rather than a synonym reused.

### the invariant that follows

> a guarantee is proven where it is **CONSUMED**, never where it is **DECLARED**.

📜 measured the same day, in the clamp written for this very defect.
`prove.apt-is-never-interactive` began with four directions — the scope, the agreement of
the declarations, the absence of any escape, and the bite. **all four stay green on a repo
whose process-wide export has been deleted**: the array still exists, still agrees with the
bootstrap, and every call site still routes through the boundary.

so a fifth direction was owed, and it reads the guarantee out of a CHILD PROCESS's own
environment. that is the only place an export can be observed, and an expansion that parses
is not an expansion that exports.

## .the rule it yields

1. a guarantee is declared ONCE and expanded, never hand-copied
2. where a copy is unavoidable — `grove.bootstrap.sh` runs before the repo exists, so it
   cannot source the boundary — the copies are CLAMPED by a play that compares them
3. a guarantee is proven at its point of consumption, in a process that inherited it
4. an artifact that is both a gate and a guarantee names which half any claim is about
