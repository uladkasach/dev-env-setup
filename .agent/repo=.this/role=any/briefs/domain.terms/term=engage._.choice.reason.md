# domain.term.choice.reason: engage

## .etymology

from the mechanical sense, the same family `bite` draws on — a clutch engages, a gear
engages, a pawl engages. the picture is a part that meets its counterpart and
transmits force.

`bite` took the half of that picture about **grip against resistance**: a brake bites,
and what it proves is that it CAN stop the wheel. `engage` takes the half about
**contact at the right moment**: a clutch engages when the driver asks and rides free
when they do not, and both halves are its job.

the two words were always one metaphor, which is precisely why the boundary needed a
written verdict rather than an author's taste.

## .why the rejected words lose

| word | why it fails |
|---|---|
| `bite` | its subject is a check's **power to refuse**. a guarantee refuses no part of what it touches — `pkg_await_apt_lock` returns 0 in every branch, by design — so there is no false direction to observe, and `bite`'s own invariant calls a `prove.*-bites` play with no red arm misnamed |
| `work` | the exact failure `bite` rejected it for, one axis over: a guarantee that never engages still "works" on every healthy run |
| `fire` / `trigger` | say the guarantee ran. a wait that always waits fires perfectly and taxes every run |
| `activate` | names a state change. the claim is not that it turned on, but that its EFFECT landed where it was owed and nowhere else |
| `apply` | taken, and load-bear: `--mode apply` is the write mode of every bundle |
| `hold` | taken, and it names the other subject entirely — a box in its declared state |

## .the two claims the word keeps apart

the same shape `bite` draws, with the artifact swapped for the mechanism:

```
"the apply converged"      → a fact about the BOX:       no one held the lock this time
"the wait engages"         → a fact about the GUARANTEE: a real holder is waited out
```

a run that reports only the first has proven that it was lucky with the clock. it says
**not one word** about the race the guarantee exists for — and on a converged box the
race cannot occur at all, so every green run is silent on it forever.

## .the dispute that bore the term

### dispute: `bite`, for a guarantee — raised 2026-09-02 — status: RESOLVED (new term)
- raised.by  = \<mechanic\>
- claim      = `bite` already names "a mechanism seen to do its job in both directions",
               and `pkg_await_apt_lock` was proven in both. so the play should be
               `prove.apt-lock-wait-bites`, and no new word is owed.
- counter    = `bite`'s cluster settles it against itself, in three places. its `.what`:
               *"a claim about the CHECK"*, proven *"RED against a subject deliberately
               broken"*. its `.reason`: what deserves the word is a check's **power to
               refuse**. and its own invariant: *"a `prove.*-bites` play that exercises
               only the green direction is misnamed."*
               a guarantee has no red direction to exercise. it returns 0 in every
               branch — deliberately, since the caller is the check — so the arms of
               this play are `engaged` and `stood aside`, and neither is a verdict.
- resolution = **`bite` keeps its scope; `engage` is born beside it.** the play was
               renamed `prove.apt-lock-wait-engages`, and `bite` is recorded as a
               forbidden synonym here rather than widened there. a word that covered
               both would lose the one distinction each was coined to make — verdict
               versus effect.

### ⚠️ the tell, which sat inside the artifact the whole time
the play's FILENAME said `bites` while every line of its own prose said *engage* — its
`.why` block says it twice. one artifact, two words, one concept: the exact drift the
glossary exists to catch, committed by the author of the glossary round.

⇒ so the cheap check is not a memory of the term list. it is a read of your own prose
against your own filename: **where they disagree, the prose is usually right**, because
prose is written to be understood and a filename is written to be typed.

## .evidence

- discovery: the repo already holds the NOUN (`term=guarantee`) and several instances
  — `PKG_APT_ENV`'s `NEEDRESTART_MODE=a` (whose absence once hung a grove 57 minutes),
  `GIT_TERMINAL_PROMPT=0`, the `--within` bounds, and now `pkg_await_apt_lock`. it held
  no VERB for one proven to do its work.
- `rule.require.one-command-provision` already grades guarantees in its enforcement — a
  guarantee applied to one call and not to its twin in the same file is a blocker there
  — so the concept was load-bear before it was named.
- measured 2026-09-02 on a grove's ground seat, both arms:
  ```
  ├─ A. lock free  ✔ returned in 0s, stayed silent
  ├─ B. lock held  ✔ waited 15s, announced both edges
  └─ restore       ✔ /var/lib/dpkg/lock-frontend is free again
  ```
  arm A is the one `bite` has no name for: it proves the wait does NOT tax a run that
  never owed the wait.
- invariant: a `prove.*-engages` play that exercises only the engaged arm is misnamed,
  and that is checkable by a read of its arms — the same clamp `bite` carries.
