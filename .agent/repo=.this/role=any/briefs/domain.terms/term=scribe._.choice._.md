# domain.term: scribe

term.chosen   = scribe
term.kind     = noun
term.synonyms.forbidden:
- logger
- collector
- handler
- listener
- reporter
- watchdog (reserved — a distinct sense, see below)

## .what

the in-nvim subsystem that **witnesses errors and writes them down**, so a fault survives the
session that produced it.

one scribe per nvim core. it owns two capture channels and one durable log:

| channel | what it witnesses |
|---------|-------------------|
| `vim.notify` wrapper | what a plugin **reports** about itself |
| `:messages` poll | what the **runtime throws** past `vim.notify` |

## .why not `logger`

`logger` is the obvious word and it is forbidden for one reason: **a logger is told; a scribe
observes.**

a logger is called by other code — `log.info(...)` — so its record covers only what the author
remembered to report. this subsystem is called by no one. it wraps a global, polls a history, and
catches errors from libuv timers and decoration providers whose authors never reached for a log
call at all. that involuntary, observational quality is the whole design, and `logger` denies it.

the same objection sinks `collector` (passive, implies records arrive on their own), `handler` and
`listener` (both imply a registered callback the source invokes), and `reporter` (names the read
side — that act is `review`).

## .why not `watchdog`

`watchdog` is **taken, by a neighbor in the same file**, for a different sense:

| subsystem | witnesses | acts? |
|-----------|-----------|-------|
| self-watchdog | its own rss / buffer / treesitter growth | **yes** — trips a breaker, disables handlers |
| error scribe | errors, from two channels | **no** — writes only, never intervenes |

a watchdog **intervenes**; a scribe **only records**. to call the scribe a watchdog would promise
a breaker it does not have. the two sit within 200 lines of each other, so the distinction has to
hold at a glance.

## .refs

**the contract:**

- `src/init.lua` → the `error scribe` block — the subsystem, its two channels, the exit flush
- `src/init.lua` → `_G.nvim_errorlog = { path, capture }` — the scribe's exposed handle
- writes `stdpath('state')/errors.log`

**the neighbor that holds the other sense:**

- `src/init.lua` → the `self-watchdog` block — witnesses growth, and acts

**the briefs:**

- `.agent/repo=.this/role=any/briefs/desktop/nvim/howto.review-nvim-errors.md` — "the scribe polls the message
  history every 5s"; the silent-log table routes by which channel failed

## .reason

see the ref-level file beside this choice:

- `term=scribe._.choice.reason.md` — etymology, evidence, why each synonym is forbidden
