# domain.term: duct.idle

term.chosen   = idle (with `busy` as its complement)
term.kind     = adj
term.synonyms.forbidden:
- free (says unoccupied; a duct mid-`apt` is occupied but still reachable)
- ready (a busy duct is ready to RECEIVE — it just will not run what it gets)
- available
- open (already taken: `duct.open` MAKES a duct exist; a duct can be open and busy)
- active (reads as the opposite of its sense here — an idle duct is the live one)

## .what
whether a duct will **run** what it is sent.

| state | what holds the pane | a send becomes |
|-------|--------------------|----------------|
| `idle` | a shell prompt (`bash`, `zsh`, `sh`, …) | a command the shell RUNS |
| `busy` | any other program (`apt`, `nvim`, `sudo`) | text in THAT program's stdin |

a duct is idle when a shell holds its pane, and busy otherwise. the pair is read from tmux's
own `pane_current_command`, so it is observed rather than tracked.

## .why the distinction carries weight
`duct.send` is a **keystroke**, not a queued command. it goes wherever the pane's foreground
process reads stdin — so the same send either runs or is eaten, and only this state says which.

worse, the difference is **silent**: tmux reports a delivered keystroke as success whoever
consumed it. so a send to a busy duct fails without a failure.

## .the operations it governs
- `duct.send` refuses a busy duct by default
- `duct.send --await <secs>` — poll until idle, then send
- `duct.send --anyway` — send INTO the held program on purpose (answer its prompt)

## .refs
- src/ductwork.sh                                       # `__duct_pane_command`, `__duct_pane_is_idle`
- .agent/repo=.this/role=any/skills/git.grove.send.sh   # forwards `--await` / `--anyway`

## .reason
see the ref-level cluster beside this choice:
- `term=duct.idle._.choice.reason.md` — etymology, the defect that settled it, and why the
  read is observed rather than tracked
