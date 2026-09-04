# domain.term.choice.reason: grove.send

## .etymology
inherited from **ductwork**, which names its primitives `duct.open` / `duct.send` /
`duct.read`. `grove.send` is that same verb lifted to the grove scope: ductwork sends into
a duct, `grove.send` sends to a grove and lets the duct be the transport underneath.

`send` was kept over `exec` and `run` because it names the ACT from the caller's side —
you hand a command across a boundary and it goes. `exec` and `run` describe what happens
on the far side, which is the machine's business, not the caller's. `send` also pairs
cleanly with `read` (`rule.prefer.symmetric-term-pairs`), where `exec` has no partner.

`ssh` was rejected outright: it names a transport, not an act. the whole point of the term
is that the transport varies — a duct today, plain ssh in the bootstrap window — while the
act does not.

## .the delay in itemization  —  noted 2026-07-26
this term was declared well before it was itemized. `git.grove.send` shipped with the
`git.grove.*` triad; the glossary captured `grove.wake`, `grove.stop`, `grove.push`,
`grove.pull`, `grove.alias`, and `grove.trust`, but not `grove.send` or `grove.read`.

the gap surfaced only when the round EXTENDED the term (with `--bare` and `--detach`) and
went looking for its cluster. that is a live example of why
`rule.require.domain-term-itemization` is a blocker and not a nicety: an un-itemized term
is invisible until somebody trips on its absence.

## .disputes

### dispute: bare vs a second term  —  raised 2026-07-26  —  status: RESOLVED (one term, two transports)
- raised.by  = <traveler>
- claim      = a plain-ssh send is a genuinely different act from a duct send: it does not
               survive a disconnect, it opens no session, and it leaves no scrollback. so
               it deserves its own term rather than a flag on this one.
- counter    = the ACT is identical — give a grove a command to run. what differs is the
               carriage. a caller who wants a command run should reach for one word and
               pick a transport, not choose between two verbs for one intent. a second
               term would also imply a second concept to learn, when the real lesson is a
               single constraint: a duct needs tmux, and a fresh grove has none.
- resolution = one term, `grove.send`, with `--bare` as the transport flag. the duct stays
               the default precisely because it is the better carriage; `--bare` is named
               for the bootstrap window it exists to serve.

## .evidence
- discovery: a fresh grove failed `grove.send` with `tmux: command not found` — the duct
  could not open at all, because ductwork IS tmux. that is what forced the second
  transport, and it is a bootstrap constraint, not a second concept
- the `--detach` variant was forced by a second, unrelated constraint: a `grove.provision`
  run takes 10+ minutes, so a plain ssh send dies with the connection. its stdin MUST be
  closed, else the remote job exits on EOF the moment ssh closes — the same defect that
  killed the ssm tunnel earlier in the same round
- `grove.read` is the read half; each is meaningless without the other, which is what
  makes `send`/`read` the right pair over an unpaired `exec`

## .the flag outlived its trigger — and now names it  (2026-07-27)

the round-eleven resolution ("one term, `--bare` as the transport flag") held. what did NOT hold
was the DISCIPLINE around the flag.

grove-1 was rebuilt on an image that ships tmux. the duct was verified live in the same round
(`grove.send --what 'whoami'` → `camper`, via `duct://grove-1:main`). and `--bare` was passed
anyway, for several commands after that proof. the human caught it in four words:

> why did you use bare?

the honest answer was **habit, not reason**. the trigger for `--bare` is "the duct cannot carry
this" — a duct IS tmux, and a fresh grove has none. that trigger no longer fired, and the flag
rode along regardless.

it was not free, either. `--bare` gives up exactly the property that matters most on this box: a
duct survives a disconnect, and this grove hibernates mid-job. a waiter sent `--bare` died with
its connection; the duct-borne one would not have.

**the cure was to demand the trigger at the call site.** `--bare` now REQUIRES `--why`, and the
error names the two triggers that earn it (`no tmux yet`, `duct is broken`). the flag's own help
records that `--why` is not a password but a prompt to CHECK.

### why this is the fourth instance of one pattern

`rule.require.exemptions-name-their-trigger` was written in round thirteen, after a deferral
whose trigger fired too late. the pattern has now appeared four times:

| round | the artifact | what outlived its reason |
|-------|--------------|--------------------------|
| eleven | "send/read are get-set-gen verbs, reused not re-itemized" | a **judgment** |
| thirteen | "`install_*` / `configure_*` must have a step line" | an **exemption** |
| fourteen | four references to a deleted file | a **citation** |
| fifteen | `--bare`, passed after tmux landed | an **invocation** |

the first three were WRITTEN artifacts, and their mitigations were all about the written word:
re-check the roster, name the trigger, sweep the back-links. this one differs in kind — the stale
artifact was a runtime CHOICE, made fresh each time, and no prose would have caught it. the
trigger WAS written down, in the skill's own `.note`, and the flag was still typed from habit.

**the generalizable lesson: a trigger recorded in prose is a trigger you can ignore silently. a
trigger demanded by the contract is one you must answer.** where an exemption is invoked
repeatedly, the guard belongs in the code, not the comment.
