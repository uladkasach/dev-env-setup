# F5 — enter toggles a line selection

## .the fork
- **A, taken:** enter begins a line selection; enter again ends it (copy-mode stays)
- **B:** keep tmux's stock enter (copy and leave), and start the selector some other way

## .why A
the wish names enter for both begin and end. a LINE selection (not a character one), because the wish speaks in lines: "add/remove lines from what is included".

## .rework — clean
one bind.

## .confidence — 85%
the stock enter-copies-and-leaves is gone everywhere in copy-mode, not only after super+v, since tmux has one copy-mode table.

## .where
`tmux.conf` super+v block; `visual_select.lua`
