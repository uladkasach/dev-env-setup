# howto: terminal window management

## .what

open visible terminal windows for humans via kitty IPC. composable with ductwork for persistent sessions — local or cloud.

## .why

- agents need to open terminals for human review
- separate window management (kitty) from session management (tmux)
- one terminal per duct session keeps model simple
- cloud ducts enable persistent sessions on remote machines

## .namespaces

| namespace | concern | backend |
|-----------|---------|---------|
| `duct.*` | session management | tmux (local or cloud) |
| `term.*` | window management | kitty (always local) |

## .usage

### standalone terminal

```bash
term.open --via kitty                     # open with shell
term.open --via kitty --cwd /path         # open in directory
term.open --via kitty --shell /bin/zsh    # specify shell
```

### with local duct session

```bash
# open terminal attached to local duct
term.open --via kitty --on dev

# if terminal already exists for that duct, focuses it instead
```

### with cloud duct session

```bash
# first, create headless session on cloud machine
duct.open --on vlad@cloud:agent-1

# open local kitty window attached to remote duct
term.open --via kitty --on vlad@cloud:agent-1

# kitty runs locally, ssh tunnels to remote tmux
# ctrl+x d detaches, remote session continues
# reattach anytime with same command
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

### local

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

### cloud (agent trees)

```bash
# spawn multiple agents on cloud machine
for i in 1 2 3; do
  duct.open --on vlad@cloud:agent-$i
  duct.send --on vlad@cloud:agent-$i --what "claude --task '$TASK_$i'"
done

# open local windows to watch any/all
term.open --via kitty --on vlad@cloud:agent-1
term.open --via kitty --on vlad@cloud:agent-2

# read output (no window needed)
duct.read --on vlad@cloud:agent-3

# hibernate cloud machine... sessions persist via tmux-continuum
# resume later, reattach to any session
term.open --via kitty --on vlad@cloud:agent-1
```

## .registry

terminal metadata stored in `~/.termwork/{pid}.json`:

```json
{
  "pid": 12345,
  "socket": "unix:/tmp/kitty-12345",
  "cwd": "/home/vlad/git/project",
  "duct": "agent-1",
  "host": "vlad@cloud",
  "startedAt": 1718100000000
}
```

- `host` is empty string for local ducts
- `host` is `user@hostname` for cloud ducts

## .install

```bash
source ~/git/more/dev-env-setup/src/termwork.sh
```

or add to shell config:

```bash
source ~/.bash_aliases.termwork.sh
```
