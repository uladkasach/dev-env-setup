# demo: 4.3.kitty — one absent terminfo entry, three symptoms

## .what

`grove-1`, 2026-07-29: an absent `xterm-kitty` terminfo entry gave three
unrelated complaints, and no run reported a defect.

## the trace

- tmux refused to start
- ncurses tools garbled their output
- backspace drew as a space

one absent entry, three symptoms. the entry was installed by a step only a
machine WITH a screen ever ran, so a headless box never got it, and no check
named the gap.

## .see also

- `4.3.kitty/_.sh` — the bundle split this measurement justified
- `4.3.1.terminfo/_.sh` — the child that now installs on EVERY machine
