# domain.term: host

term.chosen   = host
term.kind     = noun
term.synonyms.forbidden:
- parent
- container
- supervisor
- manager
- owner

## .what

a process that **contains** other processes rather than performs their work — a terminal, a
multiplexer server, a compositor, an init. its children are the workloads a human started; it
merely holds the ground they run on.

the property that defines it is **accountability**: a host inherits the spawn count of all that
runs beneath it, and none of the intent. so it ranks high on any parent-tally and is never the
culprit.

that makes it the exact inverse of what a blame list is for:

| | a spawner | a host |
|---|---|---|
| its count means | it forked that work | work forked beneath it |
| a kill removes | the storm | the work, and not the storm |

## ⚠️ .the hazard the word must carry

a host **reads as the top culprit on every parent-tally**, because containment and causation
produce the same number.

worse, a host can lie about itself in `cmdline`. `tmux new-session -d -s <x>` daemonizes into the
tmux *server* when none is live, and the server keeps that client cmdline for its whole life:

```
57 spawns  pid=38244  tmux new-session -d -s rhachet-brains-anthropic_beav_feat-
```

that reads like a process that spawns sessions. it is a server that holds six of them.

measured 2026-09-05: a cut made on that line killed six live work sessions and not one fork of
the storm. so a host must be classified from its own `comm`, never from its `cmdline`, and it
must never appear in a list a human is told to cut from.

## .refs

**the contracts:**

- `.agent/repo=.this/role=any/skills/machine.diagnose.churn.sh` — classifies each blamed parent
  as `host` or `spawner` by `comm`; `SPAWNERS` is the actionable list, `HOSTS` prints below it
  marked and is never a kill target

**the origin:**

- 2026-09-05 — the churn report ranked a tmux server first and advised "the heaviest parent is
  where to cut". the cut ended six work sessions; the fork rate was unaffected

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **host** | it holds the ground others run on | ✅ carries containment without agency |
| `parent` | the pid that forked it | ✗ true of a spawner too — `parent` is the fact that misleads |
| `container` | an isolation boundary (docker, cgroup) | ✗ already means a namespaced sandbox; a tmux server is neither |
| `supervisor` | it restarts what it holds | ✗ claims a lifecycle duty a terminal does not have |
| `manager` | it decides what runs | ✗ implies agency, which is the exact fact a host lacks |
| `owner` | it is accountable for them | ✗ inverts the term — non-accountability is the point |

`parent` loses on the sharpest point: every host is a parent, which is precisely why the tally
confused them. the term exists to split the two.

## .the neighbour it is NOT

⚠️ **`consumer` lists `host` among its forbidden synonyms.** that stands, and does not conflict:

- a **consumer** reads a *file* and can reject it — a (file, runtime) relation
- a **host** contains a *process* and performs none of its work — a (process, process) relation

different relata, different relation. the forbid means "do not say `host` when you mean
`consumer`", never "the word is spent". see the resolved dispute in
`term=consumer._.choice.reason.md`.

## .reason

see the ref-level file beside this choice:

- `term=host._.choice.reason.md` — etymology, the tmux-server cmdline trap in full, and why
  containment and causation are indistinguishable in a parent tally
