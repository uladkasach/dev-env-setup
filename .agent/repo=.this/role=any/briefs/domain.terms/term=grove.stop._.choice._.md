# domain.term: stop

term.chosen   = grove.stop
term.kind     = verb
term.synonyms.forbidden:
- hibernate    # ONE way to stop (suspend to disk) — a mode, not the operation
- halt         # the other way (power off) — likewise a mode, not the operation
- sleep        # reads as the grove's own idle drift, not a deliberate act
- kill         # implies violence to a process; a stop is orderly
- terminate    # aws's word for DESTROY; a stopped grove keeps its disk

## .what
drive a grove to down: close its duct, then take the box down by one of two
modes — `--how hibernate` (fast resume, RAM kept) or `--how halt` (power off, so
the next wake is a cold boot). idempotent — a stop of a down grove is a no-op.

## ⚠️ .the two modes are indistinguishable from the outside

`--how hibernate` and `--how halt` both end at a box that answers ssh on the next wake. so
**"it came back" is no evidence at all** of which mode ran — and a hibernate that silently
degraded into a halt costs the duct every session it held, with no error anywhere.

the decisive tell is `/proc/sys/kernel/random/boot_id`: the kernel mints it once per boot, so
it HOLDS across a resume and CHANGES across a boot. `btime` and a continuous uptime corroborate.

⇒ measure it with the matched pair below, `.before` then `.after`. a marker file is NOT enough —
it survives either mode, so it proves the disk and says none of the ram.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.stop.sh   # the portable stop
- src/bash_aliases.sh                                   # `git grove stop` dispatch

⚠️ a `hibernate.probe.before` / `hibernate.probe.after` pair (capture boot_id + btime + uptime,
then re-read them and judge resume vs boot) is named for the **mode**, not the operation, so
`hibernate` in the filenames
is correct and is not the forbidden-synonym violation it resembles. a probe that answered
"did `grove.stop` happen?" would be the misnamed one — these answer "which mode did it use?",
and the mode's name is `hibernate`.

## .reason
see the ref-level cluster beside this choice:
- `term=grove.stop._.choice.reason.md` — etymology, the hibernate/terminate disputes, evidence
