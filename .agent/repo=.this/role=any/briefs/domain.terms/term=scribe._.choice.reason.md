# domain.term.choice.reason: scribe

## .etymology

a **scribe** is one who witnesses events and writes them down for those who were not present. the
role is defined by two properties, both of which this subsystem has and `logger` lacks:

1. the scribe **is not summoned** — it records what happens in the room whether or not anyone asks
2. the scribe **does not act** — it holds no power over what it records

the record outlives everyone in the room. that is precisely the value here: an error scrolls off
the screen and dies with the session, so the scribe's whole purpose is to be the part that
survives.

## .evidence — the narrative that surfaced it

the discovery move was a **scenario narrative**, told from the human's side:

> nvim throws `Invalid buffer id: 15968` and the ui halts. the human cannot even quit. an hour
> later they ask what happened. the error is gone — it scrolled past, the session died, and the
> one witness to the fault was a screen that has since been cleared.

told that way, the absent piece names itself: **there was no witness that outlived the session.**
not an absent log call — the code that threw was a decoration provider that would never have made
one. what was absent was someone in the room, on watch, whose notes persist.

the subsequent design fell out of the same narrative. a witness who only hears what people
announce is a poor witness, which is why one channel (`vim.notify`) was not enough and the
`:messages` poll became the second, durable channel.

## .the distribution that confirms the split

`src/init.lua` now holds two observer subsystems within ~200 lines. walked on two axes:

| | witnesses growth | witnesses errors |
|---|---|---|
| **intervenes** | self-watchdog | *(empty — deliberately)* |
| **records only** | *(the trend log)* | **error scribe** |

the empty cell carries the weight: a subsystem that both witnesses errors **and** intervenes on
them would be an error-triggered breaker, which this repo deliberately does not have — to quiet a
leak is safe, but auto-reaction to an error risks a mask over the very fault the log exists to
expose.

so `watchdog` and `scribe` are separated on the **acts / records-only** axis, not on subject
matter. that axis is checkable, which is what makes the pair durable rather than stylistic.

## .disputes

### dispute: logger  —  raised 2026-08-11  —  status: RESOLVED (keep `scribe`)
- raised.by  = mechanic
- claim      = "logger" is the universally understood word for a component that writes a log. a
               coined word costs every future traveler a lookup that `logger` would not.
- counter    = `logger` carries a contract this subsystem does not honor: a logger is **invoked**
               by the code that wants a record, so its coverage equals what authors remembered to
               call. this one is invoked by no one — it wraps `vim.notify` and polls `:messages`
               precisely to catch what no author would ever log. a traveler who reads "logger"
               would reasonably look for the call sites, find none, and misjudge the design. the
               lookup cost of `scribe` is paid once; the wrong mental model is paid forever.
- resolution = keep `scribe`; record `logger` as a forbidden synonym. **the log file itself keeps
               the plain word** (`errors.log`) — the artifact is a log, the subsystem is a scribe.
               dispute closed.

### dispute: watchdog  —  raised 2026-08-11  —  status: RESOLVED (keep both, distinct senses)
- raised.by  = mechanic
- claim      = `src/init.lua` already calls its observer a "self-watchdog". a second observer in
               the same file should reuse the extant word rather than add one.
- counter    = the extant watchdog **trips a breaker** — it disables minimap and treesitter, and
               notifies. the scribe deliberately never intervenes. one word over both would
               overload it across the acts/records-only boundary, and the practical cost is a
               false promise: a traveler who chases an error storm would look for the breaker that
               stopped it, and find none.
- resolution = keep both. `watchdog` is forbidden **as a synonym of** `scribe`, not as a word.
               dispute closed.

## .invariants

- a scribe MUST NOT intervene — it never disables a handler, kills a process, or alters the
  behavior it observes. the moment it acts, it is a watchdog and must be renamed
- a scribe MUST survive its session — a record that dies with the process is not a scribe's record
  (hence the durable path under `stdpath('state')`, never `/tmp`)
- a scribe MUST NOT depend on invocation — coverage that requires an author to opt in belongs to a
  logger, not a scribe
