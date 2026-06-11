# howto: headless terminal streams

## .what

run terminal sessions headless (no display), attach later from any terminal — local or remote.

## .why

- start long jobs without a window
- detach when you close laptop, reattach later
- survive terminal crashes
- sessions persist across reboots (via continuum)

## .usage

### local

```bash
duct.open --on work                      # start headless
duct.open --on work --mode headfull      # attach (ctrl+x d to detach)
duct.send --on work --what "npm run dev" # send command
duct.read --on work                      # peek at output
duct.stop --on work                      # kill session
duct.list                                # list local sessions
```

### remote (cloud)

```bash
duct.open --on user@host:work                      # start headless on remote
duct.open --on user@host:work --mode headfull      # ssh + attach
duct.send --on user@host:work --what "npm run dev" # send command
duct.read --on user@host:work                      # peek at output
duct.stop --on user@host:work                      # kill session
duct.list --on user@host                           # list remote sessions
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
   │  ctrl+x d                 │
   ├──────────────────────────►│ (detach, session continues)
   │                           │
   │  duct.open --on work      │
   │    --mode headfull        │
   │◄──────────────────────────┤ (reattach anytime)
```

## .scrollback

peek via `duct.read --on work` (no attach required).

captures last 500 lines from tmux scrollback buffer.

## .persistence

sessions survive reboots via tmux-continuum:
- auto-saves every 15 minutes
- auto-restores on tmux start

manual save/restore:
- `ctrl+x ctrl+s` — save
- `ctrl+x ctrl+r` — restore

## .install

```bash
source ~/git/more/dev-env-setup/src/install_env.pt2.shell.sh
install_cli_deps   # includes tmux
configure_tmux     # installs tpm + plugins automatically
```
