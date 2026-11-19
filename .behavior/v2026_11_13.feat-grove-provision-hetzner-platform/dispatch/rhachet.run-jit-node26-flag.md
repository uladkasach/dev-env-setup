## .what

`rhachet/bin/run.jit` (rhachet@1.51.0) launches node with `--experimental-transform-types`. node 26 removed that flag, so every `rhx` call on a node-26 box dies before it starts:

```
node: bad option: --experimental-transform-types
```

## .measured

- 2026-11-14, a fresh grove whose default node followed `lts-latest` to v26.13.1
- same install, node v22.21.0: `rhx keyrack --help` answers
- node v26.13.1: the line above, exit 9

## .why it matters

lts-latest is v26 now, so any box provisioned from today with a default lts node has no `rhx` that runs: no keyrack, no rack, no skills.

## .the shape of the fix

choose the flag per node major in `run.jit`: type strip is stable on node 26, so the flag can drop there and stay for older majors.

## .stopgap downstream

dev-env-setup pins the box default node to its `.nvmrc` (22.21.0) until a release lands.
