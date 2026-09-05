# domain.term.choice.reason: duct.idle

## .etymology

*idle* names a machine that is powered and waits for work — the sense in "idle engine". that is
exactly a shell at a prompt: alive, reachable, and about to run whatever it is handed. its
complement *busy* likewise says occupied rather than broken, which is the honest read of a duct
mid-`apt`.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `free` | says unoccupied. a duct mid-`apt` is very much occupied, yet still reachable, still holds its scrollback, and still survives disconnect — each promise a duct makes |
| `ready` | a busy duct IS ready to receive. tmux delivers the keystroke either way. what changes is whether the recipient RUNS it |
| `available` | same defect as `free`, with more syllables |
| `open` | already taken, and correctly: `duct.open` MAKES a duct exist. a duct can be open and busy at once, so the words must not collide |
| `active` | inverts the sense. under `active`/`inactive` the idle duct reads as the dead one, when it is the one able to work |

## .what settled it — a `true` eaten by apt

I sent `true` to grove-1's duct while a `--for cloud --mode apply` was mid-run. it surfaced in
the scrollback spliced into apt's own progress line, because `tmux send-keys` types at the pane
and apt held the terminal.

`duct.send` reported `🔧 duct://grove-1:main sent`. it had, in the only sense tmux measures.

the human named the work:

> yeah, how do we fix duct.send ?

## .the defect shape — a success that is not one

three properties made this worse than a plain failure:

1. **silent** — tmux counts a delivered keystroke as success whoever consumed it. there is no
   error to read, so the caller believes the command ran
2. **unbounded** — a send to a busy duct puts arbitrary text into whatever holds the terminal.
   the observed case was `true` into apt. the same slip reaches an editor, an `rm -i` prompt, or
   a `sudo` password read
3. **invisible in the artifact** — a play file can be reviewed before it runs, per
   `term=playbook`. but the review says what the play DOES, never what state the pane is in when
   it lands

that third point is the one worth a record: **a reviewed command is not a safe command if the
channel can misdeliver it.**

## .why the state is observed, never tracked

the easy design is a flag the ductwork sets on send and clears on completion. that is a second
source of truth and it drifts the first time a command dies, a duct is attached by a human, or a
send happens from another machine.

tmux already holds the answer in `pane_current_command`, so the read is a question rather than a
record. this follows `rule.require.judge-declared-state-not-live-state` in spirit and inverts it
in application: pane occupancy is **live by nature** — no boot replays it — so a live read is the
only honest one, and the verdict is scoped to the instant it was taken.

## .the shell list is a closed set, and that is the whole test

`__duct_pane_is_idle` matches `bash|-bash|zsh|-zsh|sh|-sh|dash|ksh|fish`. the dash-prefixed forms
are login shells, which tmux reports that way.

the set is closed on purpose: a shell is precisely a program that reads a line and executes it.
every other program reads stdin for its own ends. so the question "will this duct run what I send
it?" reduces exactly to "is a shell in front".

## .the failhide the guard nearly became

when `pane_current_command` reads empty, tmux could not be asked. the easy path treats that as
idle and sends.

that would make the guard fail open at the one moment it is most needed — an unreadable duct is
one whose state is unknown, and unknown includes busy. so an empty read refuses too, and says
that busy and idle are both possible (`rule.forbid.failhide`).

## .evidence

- the live scrollback carries the eaten `true`, spliced mid-apt-progress
- `git.grove.send`'s `-*)` catch-all forwards a flag but not its value, so `--await 600` would
  have forwarded `--await` and read `600` as the grove name. both flags are named explicitly now,
  with that reason recorded at the branch
- the narrative test: a traveler says "the duct is busy, wait for it" — the pair is spoken aloud,
  which is the bar `def.domain-discovery` sets

## .disputes

none open.
