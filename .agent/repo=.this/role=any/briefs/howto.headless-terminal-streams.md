# howto: headless terminal streams

## .what

run terminal sessions headless (no display), attach later from any terminal.

## .why

- start long jobs without a window
- detach when you close laptop, reattach later
- survive terminal crashes

## .usage

```bash
duct.open --on work                      # start headless
duct.open --on work --mode headfull      # attach (ctrl+x d to detach)
duct.send --on work --what "npm run dev" # send command
duct.read --on work | tail -100          # peek at output
duct.list                                # list sessions
```

## .workflow

```
headless                    headfull
   │                           │
   │  duct.open --on work      │
   ├──────────────────────────►│ (session runs, no window)
   │                           │
   │  duct.open --on work      │
   │    --mode headfull        │
   │◄──────────────────────────┤ (attach from kitty)
   │                           │
   │  ctrl+b d                 │
   ├──────────────────────────►│ (detach, session continues)
   │                           │
   │  duct.open --on work      │
   │    --mode headfull        │
   │◄──────────────────────────┤ (reattach anytime)
```

## .scrollback

peek via `duct.read --on work` (no attach required).

captures last 500 lines from tmux scrollback buffer.

## .install

```bash
source ~/git/more/dev-env-setup/src/install_env.pt2.shell.sh
install_cli_deps  # includes tmux
```
