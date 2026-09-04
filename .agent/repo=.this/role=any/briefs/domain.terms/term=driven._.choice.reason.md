# domain.term.choice.reason: driven

## .etymology
from `rule.require.every-function-has-a-driver`, which has used **drive** since 2026-07-31 for
the act: *"every function this repo declares must be REACHED by a phase that `bundle.upgrade`
drives."* the rule needed the verb and never needed a word for the SET, because it asked about
one function at a time.

a static play asks about the set, so the set needed a name. `driven` is the past participle
already in the repo's mouth — no new coinage, and its shape conforms to
`rule.require.order.noun_adj` as an adjective a corpus carries.

## .the trigger — one word decided whether a check was a clamp or a regression
2026-08-15. `prove.git-never-prompts` swept `src/**` on its first run and printed **five rows**
in `src/bash_aliases.sh`:

```
   ✋ src/bash_aliases.sh:… — git fetch, with NO GIT_TERMINAL_PROMPT=0
```

every one of those rows was TRUE about the text and WRONG about the subject. those lines are
`git.tree`, `git.grove.*` — aliases a human types. for a human, a credential prompt is the
affordance that lets them authenticate, so the play's own `fix:` line would have removed the
only way a laptop human logs in.

hours later `prove.rack-reads-stand-in-a-root` reached the identical fork over
`use.ahbode.camp`, which reads the rack from whatever repo the human chose. same shape, same
answer, and by then the boundary had a name — so the second play cost one paragraph rather than
one investigation.

⇒ **that is the case for a term rather than a comment.** the first play argued the boundary in
prose; the second reused it. a third would have re-argued it, and one of the three would have
drawn the line somewhere else.

## .the discovery worth a record — the caller, not the path
the obvious cut is by DIRECTORY, and it is wrong in both directions:

| file | under `src/`? | driven? |
|---|---|---|
| `src/bash_aliases.sh` | yes | **no** — a human types it |
| `grove.bootstrap.sh` | **no** — repo root | yes — the readme drives it |
| `src/git-credential-keyrack.sh` | yes | yes — **git** invokes it |

the third row is the one that settles it. it lives beside the human-typed artifacts, is copied
onto a box exactly as they are, and is driven — because the caller is a program. no path
predicate separates it from its neighbours.

⚠️ and `grove.bootstrap.sh` is the mirror: it is this repo's one documented exemption from the
bundle rule, so a `src/`-scoped sweep drops the artifact most apt to have drifted
(`rule.require.every-function-has-a-driver`, `.an exemption is also a BLIND SPOT`). that
measurement predates this term and is the reason both plays name the bootstrap explicitly.

## .the synonyms declined, and why each fails the polarity test
the glossary's own cheaper test asks: **would a repair be right or wrong here?**
(`term=gap._.choice.reason.md`). each rejected word admits members for which the answer flips:

- **`source`** — admits `bash_aliases.sh`, where every demand this word licenses is a
  regression. that is polarity inverted, which is the one disqualifier the test names.
- **`prodcode`** — borrowed from `define.prodcode-testcode`, and its cut is test-vs-prod. a
  fixture file inside a play is testcode and is not the question; a human's alias is prodcode
  and is also not the question. the word cannot see this axis at all.
- **`internal`** — every file here is internal. a word that admits the whole repo names none of it.
- **`tracked`** — git's, and it admits `notes/`, `keeb/`, `.dream/`, which no runtime executes.
- **`scanned`** — the near miss, and worth a line: it reads well inside a play, and it names the
  READER's act. a file is driven whether or not a play was ever written about it, so `scanned`
  would make the property depend on its observer. that is the same defect
  `rule.require.judge-declared-state-not-live-state` guards against, one level up.

## .disputes
none yet. the word is one round old, and the two plays that use it agree on every member.

⚠️ the trigger to open one: a THIRD caller class that is neither the runtime nor a human — a
cron, a systemd unit, a git hook. `machine/` already holds systemd units, and they are copied by
five bundles but executed by systemd. today they are driven under this definition ("another
PROGRAM executes it"), and no play has yet had to decide whether a unit's constraints match a
bundle phase's. when one does, this cluster earns a dispute rather than a quiet stretch.

## .evidence
- `prove.git-never-prompts` — direction 0's `🛑 .the SUBJECT is what this repo DRIVES`, with the
  five spared rows named and the reason recorded inline
- `prove.rack-reads-stand-in-a-root` — the same block, the same day, reused rather than re-argued
- `gotcha.a-check-that-cries-wolf-gets-silenced`, m.7 — *a check whose red is a plausible,
  specific, wrong fix is worse than one that prints a bare complaint*
- `gotcha.a-tool-found-by-path-answers-only-a-human` — the measurement that first split these
  two callers apart, four rungs deep, on 2026-08-10

## .refs
- `term=declared` / `term=live` — a different axis: those cut STATE, this cuts the CALLER
- `term=tree` — a branch workspace on a grove; each names a set of files, and the sets share no
  member
- `term=fixture` — a fixture's arms are synthetic and are never driven, by construction
