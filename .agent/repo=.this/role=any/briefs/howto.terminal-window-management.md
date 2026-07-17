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

### roles (one terminal, many role tabs)

one kitty window can host several ducts as tabs — one per role. a role's duct is
found at `<terminal>/<role>`.

```bash
# ductwork creates the role sessions first
duct.open --on worktree/mechanic
duct.open --on worktree/foreman

# first --for opens the terminal, its base tab is the mechanic role
term.open --via kitty --on worktree --for mechanic

# a later --for adds a tab for the foreman role
term.open --via kitty --on worktree --for foreman

# address a role's tab for read/send/stop
term.read --via kitty --on worktree --for foreman
term.send --via kitty --on worktree --for foreman --what "cmd"
term.stop --via kitty --on worktree --for foreman   # close just that tab
term.stop --via kitty --on worktree                 # close the whole terminal
```

- `--for <role>` = `--tab <role> --duct <terminal>/<role>` — the tab bar shows the
  clean role, while the tab attaches the (possibly longer, globally-unique) session
- terminal identity stays `<terminal>` (`--on`), so `--on` finds it for every role
- `--for` is local-only in v1

low-level tab primitives (what `--for` is built on):

```bash
term.open --via kitty --on dev --tab aux            # add tab 'aux' (session 'aux')
term.open --via kitty --on dev --tab aux --duct srv # tab 'aux', session 'srv'
term.read --via kitty --on dev --tab aux            # read tab 'aux'
term.stop --via kitty --on dev --tab aux            # close only tab 'aux'
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
  "duct": "worktree",
  "host": "",
  "tabs": [
    { "slug": "mechanic", "kittyId": 1 },
    { "slug": "foreman", "kittyId": 2 }
  ],
  "startedAt": 1718100000000
}
```

- `host` is empty string for local ducts
- `host` is `user@hostname` for cloud ducts
- `duct` is the terminal identity (the `--on` value), not the attached session
- `tabs[].slug` is the tab title + addressable id; the base tab is `tabs[0]`

## .install

```bash
source ~/git/more/dev-env-setup/src/termwork.sh
```

or add to shell config:

```bash
source ~/.bash_aliases.termwork.sh
```
