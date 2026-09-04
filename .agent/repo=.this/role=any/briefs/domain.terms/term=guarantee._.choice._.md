# domain.term: guarantee

term.chosen   = guarantee
term.kind     = noun
term.synonyms.forbidden:
- gate         (a gate DECIDES on an answer; a guarantee asks no question and yields no
                answer. it makes the bad case unreachable — see `.what`)
- check        (a check REPORTS. a guarantee reports never, which is exactly why it needs a
                different clamp — see `.why the distinction is load-bear`)
- guard        (already bound twice: bhrain binds it to a stone's validation file, and
                `gate` forbids it for the same reason)
- safeguard    (a synonym of guard, and it reads as a fallback for when something else
                failed. a guarantee is not a fallback; it is the thing that holds)
- precondition (names what must be TRUE before a step, which is a gate's subject. a
                guarantee is what a step SETS so a later question cannot arise)
- default      (names a value chosen when none is given. a guarantee is not overridable by
                the caller — that is the point of it)

## .what
a **guarantee** is state a run SETS so that a bad case can never arise — as against a
**gate**, which asks a question, and a **check**, which reports an answer.

| kind | asks a question? | on drift, it… |
|---|---|---|
| check | yes | **reports** — a line goes red |
| gate  | yes | **decides** — later work is skipped |
| guarantee | **no** | **hangs, or silently permits** — no line is emitted at all |

the worked examples in this repo:

```
PKG_APT_ENV               no package may ask a question
CI=1                      corepack and pnpm assume yes
sudo -n                   privilege fails rather than prompt
set -uo pipefail          an unset read is fatal rather than empty
web_fetch's time bound    a stalled transfer ends rather than waits forever
```

⇒ so *"is this a guarantee?"* is answered by what its ABSENCE would do. remove a check and
a page loses a row; remove a gate and work runs that should not have; remove a guarantee
and a box waits on a menu nobody can see.

## .why the distinction is load-bear
`rule.require.every-function-has-a-driver` states it in one line:

> a copy of a **guarantee** is worth more than a copy of a **check**, because a check that
> drifts **reports**, and a guarantee that drifts **hangs**

that asymmetry changes how each must be clamped:

| | a check | a guarantee |
|---|---|---|
| a drifted copy is found by… | its own red, on the next run | a play written on purpose to compare the copies |
| it is proven where it is… | DECLARED — the check is the artifact | **CONSUMED** — an export that parses is not an export that exports |

📜 measured 2026-08-13, both halves in one defect: the root dispatch held a hand copy of
`PKG_APT_ENV` that had drifted to one of three members, and the absent one
(`NEEDRESTART_MODE`) is the one that once wedged a box for 57 minutes. No run reddened, no
verify failed, and the copy had been wrong long enough that no one could date it.

⚠️ and the clamp written for it nearly reproduced the second half: its first four
directions all stay green on a repo whose process-wide export was DELETED. only a read of
a child process's own environment can prove a guarantee arrived.

## .what a guarantee is NOT
- it is not a gate that always passes. a gate that always passes is a defect; a guarantee
  asks no question, so it has no verdict to be wrong about
- it is not a default. a caller may override a default and may not override a guarantee
- it is not exempt from proof. it is exempt from SELF-report, which is the opposite —
  it needs more proof than a check does, not less

## .refs
- src/grove.pkg.sh                                   # `PKG_APT_ENV`, the canonical one
- src/grove.provision._.sh                             # `CI=1`, and the braces that expand the array
- grove.bootstrap.sh                                 # `BOOTSTRAP_APT_ENV`, the exempt copy
- src/grove.provision/2.shell/2.5.zsh/configure.upsert.sh   # `sudo -n`, a guarantee in a gate's clothing
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.every-function-has-a-driver.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.one-command-provision.md

## .reason
see the ref-level cluster beside this choice:
- `term=guarantee._.choice.reason.md` — the etymology, the boundary against `gate`, and the
  measurement that made the split worth a word
