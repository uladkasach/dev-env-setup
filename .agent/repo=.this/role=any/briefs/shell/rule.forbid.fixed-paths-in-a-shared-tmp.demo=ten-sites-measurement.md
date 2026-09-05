# demo: shared /tmp — the ten-site measurement behind the rule

## .what

`rule.forbid.fixed-paths-in-a-shared-tmp.md` states the rule. this brief
holds the measurement that found it: ten upsert phases wrote to a fixed
`/tmp` name, four of them fed to root.

## m1 — four sites hand a fixed path straight to root

```
sudo tar -xzf /tmp/nvim-install/<tarball> -C /opt      ← 4.5.nvim
sudo /tmp/aws-cli-install/aws/install                  ← 5.6.aws
apt-get install /tmp/session-manager-plugin.deb        ← 5.6.aws
apt-get install /tmp/<dropbox|protonvpn>.deb           ← 6.3, 6.4
```

- a `.deb`'s `preinst`/`postinst` execute as root, so the last three are code
  execution by construction
- ⇒ unprivileged → root, on the FIRST apply, on every grove

## m2 — the chain, stated once

1. `camper` creates `/tmp/nvim-install/` first, world-writable
2. `ground` runs the same bundle; its `rm -rf` cannot remove a dir it does
   not own
3. ground's fetch writes the tarball **into camper's directory**
4. between that write and `sudo tar`, camper — who owns the path — swaps the
   file
5. root extracts camper's archive into `/opt`, and `/opt/nvim/bin/nvim` is
   then symlinked onto PATH for every user

## m3 — the worst instance carried its own signature check, and lost anyway

- `4.3.2.emulator` landed the kitty tarball, its detached `.sig`, **and**
  the pinned gpg key in one shared directory
- a seat that owned that path could swap all three together, so the verify
  would check a forged tarball against a forged signature under a forged
  key — and pass
- ⇒ a check whose entire evidence set is attacker-writable is not a check.
  the sha256 pin is a separate constant in the source and would still have
  bitten — defence in depth as intended, and not a reason to leave the first
  layer open

## .see also

- `rule.forbid.fixed-paths-in-a-shared-tmp.md` — the rule this measurement
  backs
- `diagnose.shared-tmp-on-a-two-seat-box` — the probe that found it
