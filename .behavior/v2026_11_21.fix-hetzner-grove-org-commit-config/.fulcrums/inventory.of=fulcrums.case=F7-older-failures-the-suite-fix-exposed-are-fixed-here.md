# F7 — older failures the suite fix exposed are fixed here

## .the fork

5.3 fixed `play.run --all`, which handed its queue to each play's stdin and so stopped after 21 of
73 plays. the suite then reached plays no run had graded, and two failed, both older than this
branch and outside its subject:

- `prove.spinner-judges-the-burn-now` pins its old arm to a commit the #168 squash erased
- `prove.headers-carry-their-weight` finds the kitty and nvim configure verifies over 250 lines

| option | for | against |
|---|---|---|
| fix both here (taken) | 5.3 owns every failure, whatever its origin; the suite this branch repaired then ships green | two bundles outside this work enter its diff, a scope a reviewer must read past |
| ship the suite fix here, and the two repairs in their own pr | a diff that holds only this work | the suite fix ships a red suite; the next run of `--all` fails on a cause this branch found and left |

## .taken, and why

fix here. each repair is the smallest one in its file's own pattern: a pin moved to a commit on
main, and code moved into `_.sh` beside the operations already there, byte for byte. the laptop
plan of each bundle prints every claim as before.

## .rework

clean: the three files revert alone, and the two repairs move to a pr of their own.

## .confidence — 85%

low because the kitty and nvim moves reach bundles a reviewer of this work does not expect to read.

## .where

`.play/permanent/prove.spinner-judges-the-burn-now.play.sh` ·
`src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/{_.sh,configure.verify.sh}` ·
`src/grove.provision/4.terminal/4.5.nvim/{_.sh,configure.verify.sh}`

## .verdict

open — for the council.
