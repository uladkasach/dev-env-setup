# domain.term.choice.reason: breaker.trip

## .etymology

from the electrical sense: a breaker **trips**. the word is the object's own verb, so it needs
no defense of its own — it inherits `term=breaker`'s image whole.

⚠️ the declaration is spelled `trip_breaker` (verb-first, per `rule.require.treestruct`) and the
TERM is spelled `breaker.trip` (context-prefixed, per the glossary's scope rule). that is not a
drift. a term names its bounded context first so the glossary composes; a function names its
verb first so autocomplete groups by action. the two conventions disagree on order by design,
and `git.grove.play.await` already carries the same flip.

## .disputes

### dispute: fire  —  raised 2026-09-06  —  status: RESOLVED (keep `trip`)

- claim      = `fire` is the plainer english and needs no electrical metaphor to read. "the
               breaker fired" is understood by anyone.
- counter    = `fire` names the MOMENT and the trip is the ACT. a breaker that fired might have
               done much or none of what follows; a breaker that tripped has disabled,
               reclaimed, and reported. the round that settled this term found its defect in
               step 2 and its `failhide` in step 3 — both invisible to a word that stops at the
               threshold. `fire` is also already ambiguous against a timer that fires every
               tick, which is the OBSERVER half and must not share a verb with the half that
               deletes.
- resolution = keep `trip`; record `fire`, `panic`, `cut`, `activate` as forbidden synonyms.
               dispute closed.

## .evidence

the verb earned its scope from what a trip costs, measured 2026-09-06:

- **the latch makes it irreversible for the session.** `tripped` is set before the first cut, so
  no later tick can undo or re-run it. a word that read as repeatable would invite a caller to
  treat a trip as recoverable, and there is no recovery short of a restart.
- **step 2 deleted state no step could rebuild.** the reclaim wiped the buffer
  `neominimap/buffer/internal.lua:25` caches for the life of the module. every subsequent
  refresh threw `Invalid buffer id: 2` — so the trip's damage outlived the pressure it fired
  over by hours.
- **step 3 reported a remedy on a native leak it could not deliver.** `collectgarbage` returns
  lua memory only. 63 trips accrued before the census was added that names what was actually
  returned.

⇒ each of the three costs sits in a different step, which is the argument for a verb that spans
all three rather than one that names the threshold.
