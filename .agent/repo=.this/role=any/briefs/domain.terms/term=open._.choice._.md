# domain.term: open

term.chosen   = open
term.kind     = verb, and adj
term.boundary = —   # BARE, on purpose. it spans two families and one state; see `.why bare`
term.synonyms.forbidden:
- launch      # names a one-shot spawn, with no state left behind to stop
- create      # non-idempotent, and a duct or a window is re-opened, never re-created
- init        # names a first-time setup; `open` is re-run every session
- live        # a near-neighbour, and taken: `term=live._.choice._.md`

🛑 **`start` is NOT a forbidden synonym.** it was, until 2026-09-06, and the dispute that
settled it found the two words name **two concepts**, not one — so `start` is now a term of
its own (`term=start._.choice._.md`). the split:

| word | names | shape |
|---|---|---|
| `start` | the ACT that puts a resource live | an instant |
| `open` | the STATE it is left in | a duration |

## .what

the state a resource is in while it is live and reachable — and, in the two families
below, the act that puts it there.

## .the members

| operation | what it opens | what stops it |
|---|---|---|
| `duct.open` | a tmux session that carries commands to a grove | `duct.stop` |
| `term.open` | a terminal window | `term.stop` |

⇒ each leaves behind a resource that is **still there afterward**, with a name, a state,
and a way to end it.

## .the state, everywhere

`open` is also the word an artifact ANSWERS with, in a family whose act is `start`:

```
"status": "open"     # audio.record.start writes it
                     # audio.record.list  reads it back to tell a live take from a cut one
```

⇒ so a take is **started**, and is then **open** until it closes. one act, one state, two
words — which is the whole outcome of the dispute below.

## ⚠️ .why BARE, and not qualified per family

`rule.require.boundary-qualified-terms` asks *"$word, of WHAT?"* — and here the honest
answer is one word: **a resource**. duct, window, take. the state means the same in each,
so a boundary per family would declare three terms where the domain holds one, which is
`rule.forbid.domain-term-inconsistency` from the other direction.

⇒ the boundary lives on the operation's OWN name (`duct.open`, `term.open`), never on this
term.

## .refs
- `.agent/repo=.this/role=any/skills/duct.open.sh`
- `.agent/repo=.this/role=any/skills/term.open.sh`
- `.agent/repo=.this/role=any/skills/audio.record.start.sh`   # writes `"status": "open"`
- `.agent/repo=.this/role=any/skills/audio.record.list.sh`    # reads it back

## .reason
see the ref-level cluster beside this choice:
- `term=open._.choice.reason.md` — the etymology, and the `start` dispute a human raised
  and settled on 2026-09-06
