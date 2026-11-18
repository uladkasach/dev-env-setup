# F3 — ctrl+c copies and keeps copy-mode and the selection

## .the fork
- **A, taken:** copy, stay in copy-mode, keep the selection; with no selection, leave
- **B:** copy and leave, as the prior bind did

## .why A
the wish orders the keys: ctrl+c copies, THEN enter ends the selector, THEN ctrl+x or super+v leaves. that order only makes sense if the copy leaves the selector open. the no-selection exit keeps the escape the prior bind gave.

## .rework — clean
one bind: `copy-selection-no-clear` ↔ `copy-selection-and-cancel`; in the overlay, `"+ygv` ↔ `"+y`.

## .confidence — 80%, why not higher
it changes a bind the wisher already used daily: a mouse-scroll into copy-mode then ctrl+c used to copy AND return to the prompt; now it stays.

## .where
`tmux.conf` copy-mode block; `visual_select.lua`
