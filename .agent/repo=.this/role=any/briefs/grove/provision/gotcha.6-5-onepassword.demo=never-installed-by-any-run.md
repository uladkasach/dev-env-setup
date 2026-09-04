# demo: 6.5.onepassword — never installed by any run, on any machine

## .what

one measurement traced why `6.5.onepassword` was a repair, never a restoration.

## the trace

`install_1password` stood in `install_env.pt5.devtools.sh` and reached no bundle.
main was read before that claim was written. it reached no driver either —
`install_env._.sh`'s pt5 list ran `install_node`, `robot_brains`, `psql`,
`aws_cli`, `aws_ssm`, `terraform`, `docker`, `clone_org_repos`, and stopped.

so 1password was never installed by any run, on any machine. every box that had
it got it by hand.

## why that mattered

`op` is a hard dependency of two utilities this repo ships and documents:

```
src/backup_env.sh:95         reads `op` to push untrackable secrets out
src/util.yubikey.ssh.sh:111  reads `op` to restore a key onto a yubikey
```

a laptop built from the bundle tree got both scripts, both of which name `op` in
their own instructions, and no `op`. the failure landed at the moment a human
reached for a credential — the worst moment for a dependency to be absent, and
the furthest from the install that omitted it
(`rule.require.bundles-own-their-dependencies`).

## .see also

- `6.5.onepassword/_.sh` — the bundle this measurement justified
- `rule.require.bundles-own-their-dependencies`
