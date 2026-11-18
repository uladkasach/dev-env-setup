# F1 — no tmux → an nvim overlay is the selector

## .the fork
- **A, taken:** open kitty's scrollback in an nvim overlay (`launch --type=overlay --stdin-source=@screen_scrollback`), with buffer maps for the gesture
- **B:** a kitten that drives kitty's own selection from the keyboard
- **C:** support super+v in tmux only

## .why A
kitty 0.47 has no keyboard selection mode. B would rebuild one inside a kitten against an undocumented api. nvim's linewise visual mode already IS the wished-for "like in nvim", and the real init.lua brings the clipboard yank and the copy toast for free. C drops half the wish ("both with and without tmux").

## .rework — clean
the kitten's no-tmux branch is one call; swap it, and the tmux branch is untouched.

## .confidence — 85%, why not higher
the wisher asked "pseudo (or literal?)"; an overlay is literal nvim but a separate window, and may feel heavier than a mode in place.

## .where
`src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/visual_select.py`, `visual_select.lua`
