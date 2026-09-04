# howto: headless terminal streams

## .what

run terminal sessions headless (no display), attach later from any terminal — local or remote.

## .why

- start long jobs without a window
- detach when you close laptop, reattach later
- survive terminal crashes
- sessions persist across reboots (via continuum)

## .the address — a duct uri, and only that

`--on` takes a **duct uri**. there is no second form: what every message prints is exactly
what the flag accepts, so an address is copied from output back into input.

```
duct://<host>/<tree>/<role>    remote — the host is the authority
duct:///<tree>/<role>          local  — an EMPTY authority means this machine
```

local takes **three** slashes, the `file:///` convention. a bare `worktree/mechanic` is an
error, not a shortcut — see `term=duct.uri`.

## .usage

### local

```bash
duct.open --on duct:///worktree/mechanic                      # start headless
duct.open --on duct:///worktree/mechanic --mode headfull      # attach (ctrl+x d to detach)
duct.send --on duct:///worktree/mechanic --what "npm run dev" # send command
duct.read --on duct:///worktree/mechanic                      # peek at output
duct.stop --on duct:///worktree/mechanic                      # kill session
duct.list                                                     # list every duct
```

### remote (cloud)

```bash
duct.open --on duct://grove-1/main/mechanic                      # start headless on a grove
duct.open --on duct://grove-1/main/mechanic --mode headfull      # ssh + attach
duct.send --on duct://grove-1/main/mechanic --what "npm run dev" # send command
duct.read --on duct://grove-1/main/mechanic                      # peek at output
duct.stop --on duct://grove-1/main/mechanic                      # kill session
duct.list --host grove-1                                         # narrow to one MACHINE
```

`duct.list` takes `--host`, not `--on`: it narrows by machine, not by duct. reach a grove
through `rhx git.grove.send|read`, which build the uri for you
(`rule.require.reach-a-grove-through-its-duct`).

## .workflow

```
headless                                headfull
   │                                       │
   │  duct.open --on duct:///tree/mechanic │
   ├──────────────────────────────────────►│ (session runs, no window)
   │                                       │
   │  duct.open --on duct:///tree/mechanic │
   │    --mode headfull                    │
   │◄──────────────────────────────────────┤ (attach from kitty)
   │                                       │
   │  ctrl+x d                             │
   ├──────────────────────────────────────►│ (detach, session continues)
   │                                       │
   │  duct.open --on duct:///tree/mechanic │
   │    --mode headfull                    │
   │◄──────────────────────────────────────┤ (reattach anytime)
```

## .scrollback

`duct.read --on duct:///worktree/mechanic` captures the last 500 lines of the tmux
scrollback, with no attach.

## .persistence

sessions survive reboots via tmux-continuum:
- auto-saves every 15 minutes
- auto-restores on tmux start

manual save/restore:
- `ctrl+x ctrl+s` — save
- `ctrl+x ctrl+r` — restore

## .install

```bash
cd ~/git/more/dev-env-setup

# tmux, tpm, the conf, and every plugin the conf names — one bundle
rhx grove.provision --what 2.8.tmux --mode apply
```

its `configure.verify` then proves the conf is current, that **no second conf
shadows it**, and that every `@plugin` the conf names is on disk where tpm
actually puts them.
