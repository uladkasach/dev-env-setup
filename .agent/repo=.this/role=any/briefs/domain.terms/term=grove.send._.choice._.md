# domain.term: grove.send

term.chosen   = grove.send
term.kind     = verb
term.synonyms.forbidden:
- exec
- run
- ssh
- invoke
- dispatch

## .what
give a grove a command to run.

## .the two transports
one operation, two ways to carry it — the default survives a disconnect, the fallback
exists for the window before the default can work at all:

| transport | flag | what it rides | when |
|---|---|---|---|
| duct | (default) | ductwork — a headless tmux session on the grove | always, once tmux is present |
| bare | `--bare` | plain ssh, no session | the bootstrap window, before `grove.provision` lands tmux |

`--bare --detach [--log <path>]` gives the remote command its own session with its stdin
closed and its output kept in a log — what a duct would have given, for a long job that
must outlive the ssh connection that started it.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.send.sh
- src/bash_aliases.sh                  # the `git grove send` dispatcher
- src/ductwork.sh                      # duct.open / duct.send, the default transport
- .agent/repo=.this/role=any/briefs/grove/provision/howto.provision-a-grove.md

## .the pair
`grove.send` writes to a grove; `grove.read` reads what came back. neither is itemized
without the other — see `term=grove.read._.choice._.md`.

## .reason
see the ref-level cluster beside this choice:
- `term=grove.send._.choice.reason.md` — etymology, disputes, evidence
