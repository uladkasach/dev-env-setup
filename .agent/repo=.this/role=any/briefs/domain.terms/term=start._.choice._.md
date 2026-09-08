# domain.term: start

term.chosen   = start
term.kind     = verb
term.boundary = —   # BARE. it names an ACT, and the act is the same whatever is started
term.synonyms.forbidden:
- begin       # a bare synonym, and it reads as prose rather than a command
- launch      # names a one-shot spawn; a started take is tended for its whole life
- run         # taken, and far broader: `rhx` runs every skill there is
- capture     # names the RESULT, not the act — and `record` already holds that sense
- open        # a DIFFERENT concept: the state, not the act. see below

## .what

put a resource live, at this instant. the act — never the state it leaves behind.

## 🛑 .the split it was born from — `start` is the ACT, `open` is the STATE

`start` exists because one word carried both senses until 2026-09-06, and a human read the
wrong one off a command line:

| word | names | shape | the sentence it fits |
|---|---|---|---|
| `start` | the act | an instant | *"i started the take at 14:02"* |
| `open` | the state | a duration | *"the take is still open"* |

⇒ a take is **started**, and is then **open** until it closes. the sidecar carries
`"status": "open"` and `audio.record.list` reads it back — so both words are live, in one
file, and neither is a leftover of the other.

⚠️ **this is not a rename half-done.** an act and the state it produces are supposed to
have two words — `stop`/`stopped`, `wake`/`awake`. a reader who "finishes the rename" by a
change of `"status": "open"` makes every take captured before today read as an unknown
status, and `audio.record.start.sh` carries a 🛑 block at that write site to say so.

## .the members

| operation | what it starts | what stops it |
|---|---|---|
| `audio.record.start` | a take, which then fills itself from a mic | `ctrl-c` |

⇒ one member today. the word was coined for a family of one because the DISPUTE demanded
it, never because a pattern had emerged — which is the honest reason to record it here
rather than leave it tribal.

## ⚠️ .why it did NOT take `duct.open` and `term.open` with it

both stay `open`, and that is a decision rather than an omission:

- a duct and a window are **read as states**, constantly. `duct.list` answers which ones
  are open; a human asks *"is the duct open?"* and never *"was the duct started?"*
- a take is read the other way round. the human's whole concern is the ACT — *did the
  recorder start, and does it still capture* — because a take that never started is an
  unrepeatable conversation lost

⇒ so the split is by **which half a human asks about**, never by family membership. a
third family that grows a start/open pair earns both words too.

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.start.sh`

## .reason
see the ref-level cluster beside this choice:
- `term=start._.choice.reason.md` — the etymology, and the dispute that coined it
- `term=open._.choice.reason.md` — the dispute's own record, from the other side
