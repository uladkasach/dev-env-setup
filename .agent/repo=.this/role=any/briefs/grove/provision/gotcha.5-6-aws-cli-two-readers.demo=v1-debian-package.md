# demo: 5.6.aws — two readers, disagreed on debian's v1 `awscli` package

## .what

- 📜 measured 2026-08-14
- the upsert's skip-guard was `command -v aws`
- the verify's health test was `aws --version` matched against `aws-cli/2.*`
- debian's `awscli` package puts a v1 `aws` on PATH, which answers `command -v` and
  fails the version match

## .the sequence

- the upsert prints "already installed; skipped"
- the verify refutes it: `fix: … --what 5.6.aws --mode apply`
- that fix can never clear it — the re-apply hits the same guard, refuses again, and
  the verify prints the same line forever
- the verify DIAGNOSES the guard while it prescribes for the symptom
  (`rule.require.solve-at-cause`)

## .the repair

- one reader (`grove_provision_5_6_aws_cli_state`) answers a five-valued state, asked by
  both halves
- the upsert now installs over a `wrong` state instead of a bare skip

## .see also

- `5.6.aws/_.sh` — the header this demo backs
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, the two-readers shape
- `rule.require.solve-at-cause`
- `rule.require.bounded-probes-in-verifies`
