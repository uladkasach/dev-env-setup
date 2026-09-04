# domain.term: duct.reply

term.chosen   = reply
term.kind     = noun                 # the answer a send comes back with
term.synonyms.forbidden:
- await                              # taken: names the PRE-send idle wait — see .reason
- sync
- wait
- capture
- verdict

## .what

the command's OWN answer, carried back over the duct: its stdout and its exit code.

a duct is tmux, so a plain send is a keystroke — the caller gets the exit code of the
SEND (`0` whenever the text reached the pane) and the send's own banner as stdout.
`--reply` holds until the command finishes and returns what the command itself said.

## .the pair it completes

`send` and `reply` are the two halves of one exchange, and they split by SUBJECT:

| flag | waits for | is a fact about |
|---|---|---|
| `--await <secs>` | the pane to fall idle, BEFORE the send | the **duct** (`term=duct.idle`) |
| `--reply` | the command to finish, AFTER the send | the **command** |

they compose: `--await 600 --reply` waits for a free pane, sends, then brings the
answer back.

## .refs

- `.agent/repo=.this/role=any/skills/git.grove.send.sh`   # declares `--reply`
- `.agent/repo=.this/role=any/briefs/grove/reach/gotcha.the-duct-returns-the-send-not-the-answer.md`
- `.agent/repo=.this/role=any/briefs/evidence/rule.forbid.exemption-as-habit.md`  # why it was built

## .reason

see the ref-level cluster beside this choice:
- `term=duct.reply._.choice.reason.md` — etymology, the `await` dispute, evidence
