# howto: terminal window management

## .what

open visible terminal windows for humans via kitty IPC. composable with ductwork for persistent sessions.

## .why

- agents need to open terminals for human review
- separate window management (kitty) from session management (tmux)
- one terminal per duct session keeps model simple

## .namespaces

| namespace | concern | backend |
|-----------|---------|---------|
| `duct.*` | session management | tmux |
| `term.*` | window management | kitty |

## .usage

### standalone terminal

```bash
term.open --via kitty                     # open with shell
term.open --via kitty --cwd /path         # open in directory
term.open --via kitty --shell /bin/zsh    # specify shell
```

### with duct session

```bash
# open terminal attached to duct
term.open --via kitty --on dev

# if terminal already exists for that duct, focuses it instead
```

### window management

```bash
# by duct name (preferred for duct-attached terminals)
term.open --via kitty --on dev            # focus terminal
term.stop --via kitty --on dev            # stop terminal
term.read --via kitty --on dev            # read terminal contents
term.send --via kitty --on dev --what "cmd"  # send command

# by pid (for standalone terminals)
term.open --via kitty --pid 12345         # focus terminal
term.stop --via kitty --pid 12345         # stop terminal
term.read --via kitty --pid 12345         # read terminal contents
term.send --via kitty --pid 12345 --what "cmd"  # send command

term.list --via kitty                     # list open terminals
```

## .composition with ductwork

```bash
# create duct session
duct.open --on build

# open visible window attached to duct
term.open --via kitty --on build

# send commands (human can watch)
duct.send --on build --what "npm run dev"

# human closes window... process continues in duct
# human reopens anytime:
term.open --via kitty --on build
```

## .registry

terminal metadata stored in `~/.termwork/{pid}.json`:

```json
{
  "pid": 12345,
  "socket": "unix:@kitty-12345",
  "cwd": "/home/vlad/git/project",
  "duct": "dev",
  "startedAt": 1718100000000
}
```

## .install

```bash
source ~/git/more/dev-env-setup/src/termwork.sh
```

or add to shell config:

```bash
source ~/.bash_aliases.termwork.sh
```
