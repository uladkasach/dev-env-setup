# domain.term.choice.reason: duct.refresh

## .etymology

`refresh` is taken from the browser sense a human already holds: *the state is fine, my view of
it is stale, show me again*. that is precisely the fault — the duct's state is correct and the
client's picture of it is not.

the term is prefixed with its bounded context (`duct.refresh`) per the glossary's `.readme.md`,
because a grove could plausibly refresh too.

## .the words that lost

| word | why it lost |
|------|-------------|
| `redraw` / `repaint` | tmux's own mechanism words (`refresh-client` does the redraw). to name the operation after the call is HOW, not WHAT — the same mistake `respawn` would have been for `duct.reboot`. both stay welcome in comments |
| `reload` | implies content is re-fetched. no content moves; only the paint is redone |
| `sync` | retired repo-wide as overloaded (`term=git.repo.pull`). to reintroduce it in a new context would re-open a closed wound |
| `fix` | a one-off, and this operation converges and is safe to re-run. 📜 the original argument added *"…so it is a `repair`-family word, and `repair` is reserved as a PLAY verb"* — that reservation is void: `play.repair` was deleted on 2026-08-10 because a play may never write (`rule.forbid.repair-plays`). the one-off/converge distinction is what actually rules `fix` out, and it stands on its own |
| `reboot` | reserved, and the opposite blast radius. see the ladder below |

## ⚠️ .disputes

### dispute: `refresh` is OVERLOADED inside the duct context — raised 2026-07-29 — status: OPEN

- raised.by  = the robot that authored the term, against its own choice
- claim      = **`refresh` already means another act on `duct`, and it is not this one.**

  `duct.list --refresh` has meant "re-probe every remote host over ssh and rebuild the registry
  cache" since the registry existed. `duct.refresh` now means "tell attached clients to repaint".

  | contract | what `refresh` means there | what it touches |
  |----------|----------------------------|-----------------|
  | `duct.list --refresh` | re-probe hosts, rebuild the cache | the REGISTRY, over the network |
  | `duct.refresh` | redraw the client's screen | the SCREEN, local to the client |

  one word, two concepts, **one bounded context**. that is the exact overload
  `rule.forbid.domain-term-synonyms` and `ubiqlang.ambiguous-from-overload` forbid, and the
  glossary `.readme.md` names it as the reason terms carry their context as a prefix.

  it is worse than a plain synonym clash: a reader who knows `--refresh` re-probes over ssh will
  reasonably expect `duct.refresh` to touch the network. it does not.

- counter    = the two are told apart by SHAPE, not only by word: one is a flag on a read verb,
               the other is a verb of its own. and `refresh` is the word a human reaches for in
               both senses, so either rename costs a fluent word.

               the honest weight of this counter is LOW. "told apart by shape" is exactly the
               defence that failed for `--version local|global` (retired 2026-07-29 for a
               collision with `--for local|cloud`) and for `slug` vs `duct.uri`. this repo has
               twice ruled that a shape distinction does not rescue an overloaded word.

- the options, if it resolves against `refresh`:
  1. **rename the flag** → `duct.list --reprobe` (or `--rescan`). the flag is younger, has one
     caller, and `reprobe` is more precise about what it does — it reaches over ssh. cheapest fix,
     and it improves the loser as well as the winner
  2. **rename the verb** → `duct.redraw`. but that adopts a mechanism word, which the table above
     rejects on its own merits
  3. **keep both**, and record here that `refresh` is deliberately context-split by shape. the
     option the repo's own precedent argues hardest against

- leans      = option 1. `--reprobe` names what the flag actually does, and it frees `refresh`
               for the sense a human means first.

- resolution = OPEN. **the flag and the verb both ship meanwhile**, per
               `howto.domain-term-disputes` ("contracts keep the canonical term while a dispute
               is live"). this entry exists so the next traveler does not re-derive the clash.

> **the honest note on how this dispute was found:** it was not found by review. it surfaced
> while this very file was authored — the `.what` was already written, and the clash appeared
> only once the `.refs` were enumerated and `duct.list --refresh` sat beside `duct.refresh`.
> **the act of enumeration of a term's refs is itself an overload check**, and it is cheaper than
> any review. worth a deliberate reuse rather than luck.

## .evidence

- **discovery: a real symptom with no verb for it.** a duct whose client paints a stale frame is
  healthy — `duct.read` returns correct content while the window shows otherwise. every other
  repair verb aims at the wrong target: `reboot` kills a healthy program, `stop` destroys a
  healthy session. so the gap was a real hole in the ladder, not a nicety.
- **the pair is the point.** `refresh` and `reboot` are only meaningful together, because the
  ladder is what tells a caller which to reach for:

  | symptom | verb | what dies |
  |---------|------|-----------|
  | the picture is wrong, the duct answers | `duct.refresh` | none |
  | the duct will not answer | `duct.reboot` | the held program |
  | the duct should not exist | `duct.stop` | the session |

- **invariant:** a refresh changes no observable duct state. `duct.list` and `duct.read` must
  return byte-identical output before and after. that is what makes it the free rung, and it is
  the claim a future check should assert.
- **verified 2026-07-29**, on the headless branch:
  ```
  🔧 duct:///dev — no client attached, so no repaint is owed (headless is normal)
  ```
  exit 0 — because a headless duct on a grove has no picture to fix, so the goal is already met.
  an error there would make the verb useless on the machines this repo drives most.

## .refs
- `term=duct.reboot._.choice._.md` — the destructive twin
- `term=duct.list._.choice._.md` — carries the disputed `--refresh` flag
- `term=git.repo.pull._.choice._.md` — the precedent for retirement of an overloaded word
- `rule.forbid.domain-term-synonyms` — the rule this dispute is filed under
