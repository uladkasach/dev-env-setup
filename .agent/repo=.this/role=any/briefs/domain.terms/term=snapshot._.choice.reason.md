# domain.term.choice.reason: snapshot

## .etymology

`snapshot` was already this repo's word before the kitty bundle existed —
`machine_usage_snapshot` (owned by `1.7.usage`) had used it for a read-only
record of machine state. `4.3.4.snapshot` REUSED that word rather than coin a
second one, which is the whole point of a glossary: the noun already names
"a read-only record of a moment", and a kitty session record is exactly that.

rejected alternatives:

- **`dump`** — implies contents, and the security posture is the opposite: the
  snap reads `/proc` for paths and process names, never buffers and never an env
  block (`rule.require.security-paramount`). a reader who saw `dump` would
  reasonably fear the file held secrets.
- **`backup`** — implies restorable-by-machine. the snap is restorable by a
  HUMAN, from a printed map, and cannot rebuild a buffer. `backup_env.sh` already
  owns that sense in this repo (it pushes secrets to 1password), so `backup`
  would be an overload across two different guarantees.
- **`session-save`** — hyphenated, and `session` is already overloaded (tmux
  session, ssh session, SSM session, a human's work session).

## .disputes

### dispute: cronhook — raised 2026-07-31 — status: RESOLVED (reject `cronhook`)

- raised.by  = the migration itself; the word arrives from main
- claim      = main's `bash_aliases.sh` groups the runaway monitor and the kitty
               snap timer under one alias, `a sync.\*.cronhooks alias`, and the
               header calls them "cronhooks = timed hooks (systemd user timers)".
               so the word has real precedent and a real referent.
- counter    = it names a MECHANISM (a timer), not a subject, and it groups two
               bundles whose only similarity is that mechanism. that grouping is
               the defect: `1.6.2.monitor` watches runaway processes and
               `4.3.4.snapshot` records kitty windows, and neither informs the
               other. a bundle must sit where its dependency is
               (`rule.require.bundle-names-name-their-subject`), and a `cronhook`
               bundle would sit where its SCHEDULER is.

               worse, `cronhooks` is not even cron — it is a systemd user timer,
               so the word is wrong about its own mechanism too.

               it also names a caller a human must type. the timer it installed
               was reached by exactly one driver — the alias — so a freshly
               provisioned box got the alias and NOT the timer
               (`rule.require.every-function-has-a-driver`). to keep the word
               would have kept the shape that hid that gap.
- resolution = reject `cronhook` entirely. the timer becomes part of the bundle
               that OWNS the subject it serves, and `a sync.\*.cronhooks alias` is
               not carried across the migration. recorded as a forbidden synonym
               so the next traveler does not re-import it from main's history.

### dispute: snap — raised 2026-07-31 — status: RESOLVED (bounded allowance)

- claim      = `snap` is shorter and is what a human types
- counter    = `snap` collides with snapd/snap packages on ubuntu, which this
               repo actively avoids (`1.3.1.firefox` REMOVES the apt/snap firefox
               precisely so two builds do not race). an unqualified `snap` in a
               contract would read as the package manager.
- resolution = `snapshot` is the canonical noun for every bundle slug, file name,
               and directory. `snap` survives ONLY in the human-typed alias
               `kitty.snap` and the `~/.kitty/snaps` dir, where the `kitty.`
               prefix removes the collision. it is forbidden bare.

### dispute: snapper — raised 2026-07-31 — status: RESOLVED (bounded allowance)

- raised.by  = this round. `kitty_snap_lowbatt` needed a variable for the file it
               calls, and `SNAPPER` was the name that read best:

               ```sh
               SNAPPER="$HOME/.local/bin/kitty.snap"
               ...
               bash "$SNAPPER" --save
               ```
- claim      = a `snapshot` is the RECORD; the file that takes one is a different
               concept and deserves a different word. `-er` is english's agent
               suffix, so `snapper` is the obvious one, and a variable called
               `SNAPSHOT` that held an executable path would read as the output file.
- counter    = it is one letter from `snapshot` and one word from `snap`, so a
               scanner that reads fast will conflate all three. that is the exact
               ambiguity a glossary exists to kill.
- resolution = bounded, the same shape `payload` took beside `asset`
               (`term=asset._.choice.reason.md`): the AGENT and the RECORD are
               genuinely two concepts, so the word is allowed — but only where the
               point is that a mechanism WRITES.

               | use | verdict |
               |---|---|
               | a local var or comment that names the executable which writes | ✅ allowed |
               | a bundle slug, a file name, a dir name, an alias | ❌ forbidden — `snapshot` |
               | any reference to the RECORD it produces | ❌ forbidden — `snapshot` |

               `rule.forbid.domain-term-synonyms` already permits a synonym in a
               comment; this entry records that the judgment was MADE, so the next
               traveler does not have to re-derive it — or, worse, promote
               `snapper` into a filename because it saw the word in the source.

## .evidence

- **precedent** — `machine_usage_snapshot`, `1.7.usage`, predates this round and
  already carries the noun with the same guarantee (read-only, records a moment)
- **the two-writer split** — the subject-first choice is what let the concern
  divide cleanly by OWNER rather than by mechanism:

  | part | owner | why there |
  |---|---|---|
  | the low-battery timer | `4.3.4.snapshot` | fires with no human present; only a bundle can install it |
  | `kitty.snap`, `power.off`, `power.restart` | `2.7.aliases`, via `src/bash_aliases.sh` | one file, one writer (`rule.forbid.two-writers-on-one-artifact`) |

  a `cronhook` grouping cannot express that split, because it groups by the very
  thing the split ignores.

## .invariants

- a snapshot is READ-ONLY at capture: it reads `/proc` and `/sys`, and writes
  only into `~/.kitty/snaps`
- a snapshot records a MAP, never contents — no buffer, no scrollback, no env
- a snapshot is never claimed to be machine-restorable; the restore is a human
  reading the map (`howto.restore-kitty-session.md`)
