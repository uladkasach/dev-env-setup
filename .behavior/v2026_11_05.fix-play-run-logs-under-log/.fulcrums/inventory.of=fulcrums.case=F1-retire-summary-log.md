# F1 — retire summary.log

- fork: keep `<stamp>.pid<N>/summary.log` beside the new `<stamp>.stdout.log`, or retire it
- taken: retire. both hold the same verdict lines; two copies of one fact drift. the reader
  (`nheuron director.bar.operations.sh:173`) reads either, so no reader loses
- rework: clean — one `say()` line restores it
- confidence 85%: the wish never names summary.log; an unseen second reader could read it
- where: `play.run.sh` `--all` branch
- verdict: CONFIRMED by foreman (`.foreman/verdict.1.vision-fulcrums.md`). the reader's `*/summary.log` fallback is nheuron's to retire; foreman reports it upstream
