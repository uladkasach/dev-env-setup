# fulcrums

| case | title | rework | status | confidence |
|---|---|---|---|---|
| F1 | retire `summary.log`; the stdout log replaces it | clean | confirmed | 85% |
| F2 | the file ends at the summary line; the coda stays on the terminal | clean | confirmed | 80% |
| F3 | a same-second second run claims the next free stamp: atomic claim, bounded tries, per-play dir shares the stamp | clean | confirmed, bounded; claim via `mkdir` unless `O_EXCL` is read at source | 88% |
| F4 | an empty play index halts `--all` (exit 2, no log) rather than a `0 · 0 · 0` green | clean | confirmed by director | 85% |
| F6 | `mkdir <stamp>/` claims the stamp and holds the per-play logs; the `.pid<N>` suffix retires | clean | implied by q9 verdict; reported to foreman | 85% |
| F5 | add a hermetic ci workflow for the clamp, since no ci fires on `play.run.sh` today | clean | confirmed by director | 75% |
| F7 | a timeout, a no-verb play, and a vanished play stay `declined` in the tally; pinned by the clamp | clean | open; verdict owed by director | 70% |
| F8 | the full suite's play-only reds that keep every assert ride in this pr (two, each proven); the six that need a bundle, a finder, a seat, or a changed criterion stay out, each caught as a dream | clean | open; verdict owed by director | 80% |
| F9 | the silent wait inside one play stays out of this pr; an in-flight stderr line is caught as a dream | clean | open; verdict owed by director | 75% |
| F10 | 5.3 peer points disputed on evidence: no real-launch twin for a local shell play; `fix:` keeps absolute paths; the coda's ✋ is set by its class; the approved `verdict:`/`plays:` labels; the root decline; drift recorded; tree scope; claim terms | clean | coda: ruled by director — keep ✋; the rest open | 80% |
