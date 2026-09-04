# assets

custom assets for dev-env-setup.

## kitty-icon.png

custom kitty terminal icon.

requirements:
- 256x256 px (minimum)
- png format
- named exactly `kitty-icon.png`

the icon is declared by the `4.3.2.emulator` bundle, which resolves this dir
relative to its own checkout — so a run from a worktree finds the worktree's copy.

usage:
```sh
rhx grove.provision --what 4.3.2.emulator --mode apply
```

.note = the icon is the one part of that bundle whose absence is a 🌙 rather than
        a ✋: an absent asset says the checkout lacks a file, not that kitty failed
        to install. logout to flush the icon cache.
