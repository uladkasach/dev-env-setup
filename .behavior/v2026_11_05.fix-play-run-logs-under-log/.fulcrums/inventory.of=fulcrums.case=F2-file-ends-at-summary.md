# F2 — the file ends at the summary line

- fork: tee the whole stdout (last line `🌲 every play passed`, or blank on red), or write the
  verdict tree only (last line = the summary)
- taken: the verdict tree only. the wish's hard rule is "the last line of the newest file is the
  run's summary verdict"; the full tee breaks it on every run
- rework: clean — the coda can be moved into the tree, or appended, in one place
- confidence 80%: the wish also says "holds its stdout"; this holds all of stdout but the coda
- where: `play.run.sh` `say()`
- verdict: CONFIRMED by foreman (`.foreman/verdict.1.vision-fulcrums.md`). the wish's last-line rule governs
