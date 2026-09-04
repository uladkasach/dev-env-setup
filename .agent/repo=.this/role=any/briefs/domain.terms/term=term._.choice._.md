# domain.term: term

term.chosen   = term
term.kind     = noun
term.synonyms.forbidden:
- window
- terminal
- kitty
- pane
- tty
- console

## .what

a **term** is a terminal WINDOW on the human's own desktop — one kitty os-window, with a pid,
which this repo opens, reads, sends to, and closes.

## 🛑 .a term is NOT a duct

they are the two halves of one chain, and each `term.*` skill has a `duct.*` peer with the same
verb — so the pair is easy to mistake for a synonym set. they are not.

| | `term` | `duct` |
|---|---|---|
| what it IS | a kitty os-window | a tmux session on a box |
| where it LIVES | this desktop, always | any box, local or a grove |
| needs a display | ✔ yes | ✋ no |
| a close destroys | the WINDOW | the SESSION and its state |
| survives a reboot | ✋ no | ✔ yes, it is re-attached |

⇒ a term is the **viewport**; a duct is the **subject**. a term that shows a duct is the normal
case, and neither owns the other: close the term and the duct runs on.

## ⚠️ .the two `--on` vocabularies, which look alike and are not

`term.open --on` and `duct.send --on` each take an `--on`, in different grammars:

| skill | `--on` reads | example |
|---|---|---|
| `term.*` | `<host>:<session>` — WHERE to point a window | `grove-x:main/mechanic` |
| `duct.*` | a duct uri | `duct://grove-x/main/mechanic` |

so a duct uri handed to `term.open` is not a host, and a `host:session` handed to `duct.send`
is not a uri. the two never coerce.

## .why not the forbidden words

| word | why it is refused |
|---|---|
| `window` | every gui has one, so it picks out no subject `term.open` returns a pid for |
| `terminal` | reads as the EMULATOR (the program) as often as one of its windows |
| `kitty` | names the vendor, so the term would have to be renamed to swap emulators |
| `pane` | tmux's own word for a subdivision INSIDE a duct — one layer down |
| `tty` | the kernel device, which a term holds and is not |
| `console` | the system console, a different subject entirely |

## .refs

- `src/termwork.sh` — the implementation every `term.*` skill wraps
- `.agent/repo=.this/role=any/skills/term.open.sh`
- `.agent/repo=.this/role=any/skills/term.list.sh`
- `.agent/repo=.this/role=any/skills/term.read.sh`
- `.agent/repo=.this/role=any/skills/term.send.sh`
- `.agent/repo=.this/role=any/skills/term.stop.sh`
- `.agent/repo=.this/role=any/skills/term.operations.sh`
- `termwork.scope-boundary.md` — where a term's reach ends and a duct's begins

## .reason

see the ref-level cluster beside this choice:

- `term=term._.choice.reason.md` — etymology, the family's birth, disputes
