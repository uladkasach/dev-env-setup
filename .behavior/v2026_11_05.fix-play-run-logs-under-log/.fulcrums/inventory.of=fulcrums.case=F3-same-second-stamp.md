# F3 — two runs in one second

- fork: append a pid to the file name (`<iso>.pid<N>.stdout.log`), or claim the name with
  noclobber and wait for the next free second
- taken: noclobber + wait. the wish names `<iso>.stdout.log` exactly; a pid suffix diverges from
  the `git.repo.test` layout the reader shares
- rework: clean — one name expression
- confidence 88%: a same-second pair is rare; the wait costs at most a second per collision
- where: `play.run.sh` `--all` branch
- verdict: CONFIRMED with bounds by foreman (`.foreman/verdict.1.vision-fulcrums.md`):
  claim atomically via noclobber create, never check-then-write; bound the tries, then
  `💥 MalfunctionError` exit 1; the per-play dir shares the file's stamp
- q9 verdict by director, 2026-11-06: claim the stamp with `mkdir` (atomic by posix) unless
  `O_EXCL` in bash's `noclobber_open` is read at source in 5.1
