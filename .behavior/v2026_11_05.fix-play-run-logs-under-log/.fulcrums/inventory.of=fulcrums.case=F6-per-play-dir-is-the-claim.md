# F6 — the per-play dir `<stamp>/` IS the atomic claim

- fork: keep the per-play dir as `<stamp>.pid<N>/` and claim the stamp through a separate lock;
  or let `mkdir <stamp>/` claim the stamp and hold the per-play logs, with no pid
- taken: `mkdir <stamp>/`. the director ruled `mkdir` as the claim (q9). a pid made the old dir name
  unique only because no step claimed the stamp; once the stamp is claimed, the pid is redundant,
  and a lock beside the dir would be a third artifact per run. the human still pairs
  `<stamp>.stdout.log` with `<stamp>/` by eye — the foreman's pairing bound holds
- defense in depth: after the `mkdir` claim, the stdout log is created with noclobber, so an
  orphan `<stamp>.stdout.log` whose dir was removed is never overwritten — that try counts as a
  collision, the empty dir is removed, and the next stamp is tried
- rework: clean — one name expression
- confidence 85%: the foreman's text named `<stamp>.pid<N>/`; the intent named was the pairing
- where: `play.run.sh` `--all` branch
- verdict: implied by the director's q9 `mkdir` verdict (a claimed dir needs no pid); vision text
  conformed in 5.1; reported to foreman in the 5.1 yield, open to a clean rework
