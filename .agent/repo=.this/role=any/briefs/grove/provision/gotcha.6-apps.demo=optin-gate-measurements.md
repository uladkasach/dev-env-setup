# demo: 6.apps — the opt-in gate, proven on both box classes

## .what

`define.6-apps-is-laptop-only.md` states the two-gate rule: box class, then opt-in. this
brief holds the two runs that proved it — a grove that declines the whole section, and a
bare laptop that declines every app until `--include` names one.

## m1 — a grove declines all 14 phases, `grove-ahbode-v20260811`, 2026-08-13

```
$ … --what 6.apps --mode apply
      ├─ 6.1.flatpaks
         ├─ 6.1.flatpaks.provision.upsert
            🌙 declined — spotify, datagrip and slack are GUI clients, and
               cloud@aws.ec2 has no screen to draw one on
      …
🌲 grove.provision done — access prep · server cloud@aws.ec2 · commit none@none
```

- 14 phases, 14 declines, zero packages installed
- re-run it yourself in one command:
  ```sh
  rhx git.grove.send <grove> --reply \
    --what 'rhx grove.provision --what 6.apps --mode apply'
  ```

⇒ the section still RUNS on a grove — every phase is visited and reports — and installs
none of it. a grove fails the box gate on every bundle, so both gates close the same way.

## m2 — a bare laptop declines every app, `local@unix`, 2026-08-14

```
$ rhx grove.provision --what 6.apps --mode plan
      ├─ 6.apps
         ├─ 6.1.flatpaks
            🌙 spotify, datagrip and slack — not opted in; add it with: grove.provision --include datagrip,slack,spotify
         ├─ 6.3.dropbox
            🌙 dropbox — not opted in; add it with: grove.provision --include dropbox
         ├─ 6.4.protonvpn
            🌙 protonvpn — not opted in; add it with: grove.provision --include protonvpn
         ├─ 6.5.onepassword
            🌙 onepassword — not opted in; add it with: grove.provision --include onepassword
         ├─ 6.2.codium
            🌙 codium — not opted in; add it with: grove.provision --include codium
```

- 5 bundles, 5 declines, zero packages installed
- run it yourself, no grove needed:
  ```sh
  rhx grove.provision --what 6.apps --mode plan                   # declines all
  rhx grove.provision --what 6.apps --include codium --mode plan  # one runs
  rhx grove.provision --what 6.apps --include codum  --mode plan  # exit 2
  ```

⇒ each decline names its own `--include` fix, so the fix is discoverable from the output
alone — no second copy of the app list needs to live in the brief.

## .see also

- `define.6-apps-is-laptop-only.md` — the rule these two runs prove
- `rule.require.discoverability` — why the fix lives in the output, not in a brief
