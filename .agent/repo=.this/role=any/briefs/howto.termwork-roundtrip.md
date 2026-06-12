# howto: termwork roundtrip

## .what

full roundtrip: open terminal, start process, send commands, read output, close.

## .why

- agents can spawn visible terminals for humans
- agents can control processes in those terminals
- agents can read terminal output to verify state
- humans can watch while agents work

## .prerequisites

termwork requires an extant duct (tmux) session when using `--on`:

```bash
# create headless session first
duct.open --on mywork
```

## .roundtrip demo

```bash
# 1. open kitty attached to duct
term.open --via kitty --on mywork
# 🖥️ term://mywork opened (pid 2864895)

# 2. read terminal contents
term.read --via kitty --on mywork
# shows shell prompt, tmux status bar

# 3. send command to terminal
term.send --via kitty --on mywork --what "claude"
# starts claude in the terminal

# 4. read to see claude active
term.read --via kitty --on mywork
# shows claude welcome screen

# 5. send message to claude
term.send --via kitty --on mywork --what "say hello"
# claude receives and processes the message

# 6. read claude's response
term.read --via kitty --on mywork
# shows claude's response

# 7. close the terminal
term.stop --via kitty --on mywork
# 🖥️ term 2864895 stopped
```

## .key points

| step | command | what happens |
|------|---------|--------------|
| create session | `duct.open --on X` | headless tmux session created |
| open window | `term.open --via kitty --on X` | kitty attaches to tmux session |
| read output | `term.read --via kitty --on X` | captures terminal scrollback |
| send input | `term.send --via kitty --on X --what "cmd"` | types + enters command |
| close window | `term.stop --via kitty --on X` | closes kitty, tmux continues |

## .human can watch

the kitty window is visible on the human's screen. they see:
- commands as typed
- output as it appears
- active processes

the agent controls it programmatically while the human observes.

## .session persists

after `term.stop`, the tmux session persists. human or agent can reattach:

```bash
term.open --via kitty --on mywork  # reopens window to same session
```

## .see also

- howto.headless-terminal-streams.md — ductwork basics
- howto.terminal-window-management.md — termwork api reference
