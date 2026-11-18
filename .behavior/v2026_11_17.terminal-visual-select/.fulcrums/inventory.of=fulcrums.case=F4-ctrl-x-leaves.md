# F4 — ctrl+x (a bare ^C) leaves copy-mode, never copies

## .the fork
- **A, taken:** `C-c` in copy-mode → leave
- **B:** `C-c` → copy and leave, as the prior bind did

## .why A
kitty sends ctrl+x as the bare ^C byte, and kitty's ctrl+c arrives as `C-S-c`. so in tmux, `C-c` IS ctrl+x, and the wish names ctrl+x as an exit. under B, ctrl+x with a selection would silently overwrite the clipboard on the way out.

## .rework — clean
one bind.

## .confidence — 85%
the cost: in a terminal without this repo's kittens, ctrl+c is a bare ^C, so there it leaves rather than copies. `y` still copies. the wisher's daily terminal is kitty.

## .where
`tmux.conf` copy-mode block
