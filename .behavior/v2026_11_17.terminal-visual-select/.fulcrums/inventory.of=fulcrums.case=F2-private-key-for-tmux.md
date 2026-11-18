# F2 — super+v reaches tmux as a private key

## .the fork
- **A, taken:** kitty writes `CSI 9999 ~`; tmux names it `user-keys[0]` and binds `User0`
- **B:** kitty rewrites super+v to a key tmux models (an alt or ctrl chord), as ctrl+super+r → ctrl+alt+r
- **C:** let super+v's own CSI-u reach tmux

## .why A
C cannot work: tmux has no super modifier and forwards a bare `v` (gotcha.tmux-carries-no-super-modifier). B would claim a real chord from every app in every duct, since a root bind swallows it. A claims a sequence no key produces.

## .rework — clean
the sequence has two copies, one per runtime: `TMUX_KEY` in visual_select.py and `user-keys[0]` in tmux.conf.

## .confidence — 90%
proven by `prove.visual-select-keys`. the residue: a grove with a stale tmux.conf shows a stray `~` until provisioned.

## .where
`visual_select.py` (`TMUX_KEY`), `src/grove.provision/2.shell/2.8.tmux/tmux.conf` (super+v block)
