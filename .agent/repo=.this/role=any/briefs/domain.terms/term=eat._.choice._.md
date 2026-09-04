# domain.term: eat

term.chosen   = eat
term.kind     = verb
term.synonyms.forbidden:
- swallow     (the COMPLEMENT, not a synonym — the channel, not a receiver. see `term=swallow`)
- block       (a block stops the sender; an eat lets the sender succeed and consumes the message)
- steal       (implies a thief; the prompt does its declared job, which is the trap)
- absorb      (says it stopped there, and says no word about the reader that wanted it)
- intercept   (names a party that watched for it; a prompt eats whatever arrives next)
- queue       (a queued command still runs later — an eaten one is gone, read as an answer)

## .what

a message is **eaten** when a RECEIVER that waits consumes it, though it was
addressed to someone else.

the consumer is the **destination** — a prompt, a live job's stdin, a pane already
occupied. never the wire between them.

## .why the duct makes this the expensive half

a duct IS tmux, so a pane holds ONE reader at a time. an interactive question that
opens on that pane becomes the reader — and the next command sent down the duct
arrives as its answer:

```
✋ 'Do you want to install it? answer [y/N]:'  ← now the reader
   → the next command sent down this duct will be eaten as the answer
```

so the sender sees a clean send, the question sees a nonsense answer, and the box
reads as **hung** rather than as broken — the most expensive shape a fault has
(`prove.git-never-prompts.play.sh:8`).

## .the pair — `swallow` is OUTBOUND, eat is INBOUND

| word | who consumes | what is consumed |
|---|---|---|
| **swallow** | the CHANNEL, in transit | a signal outbound from the subject |
| **eat** | a RECEIVER that waits | a message addressed to someone else |

⇒ one prompt on one duct does BOTH at once, in opposite directions: its question is
swallowed on the way out, and it eats the next command on the way in. two words are
needed to say that, and `rule.require.grove-provision-as-the-only-entrypoint.md:131`
says it with both.

## ⚠️ .a receiver need not be a TOOL's prompt — the shell itself can be one

every ref below names a prompt some COMMAND opened, so every guard against them is a
tool flag: `sudo -n`, `CI=1`, `GIT_TERMINAL_PROMPT=0`. measured 2026-08-25, on a
from-scratch grove, a receiver evaded all of them by one layer lower:

```
zsh-newuser-install   ← the LOGIN SHELL's own first-run wizard
                        opens before any command runs, when a seat's record
                        names zsh and the seat holds no zsh startup file
```

it ate the `{` of the reply wrapper as its keypress, and the caller returned 97.

⇒ when you hunt receivers, ask what opens **before** your command, not only what your
command opens. see the `.reason` for the pane transcript and the repair.

## .refs
- src/grove.provision/2.shell/2.5.zsh/provision.upsert.sh          # the LIVE eat, and its repair, inline
- .agent/repo=.this/role=any/skills/git.grove.send.sh:439         # "the line was eaten as a live job's stdin"

## .reason
see the ref-level cluster beside this choice:
- `term=eat._.choice.reason.md` — why the receiver half earns its own verb, and the
  two drift sites recorded against it
