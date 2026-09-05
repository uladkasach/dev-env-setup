# domain.term.choice.reason: duct

## .etymology

a duct is the fixed passage a building runs air through — installed once, always there,
carrying whatever is put into it to wherever it goes. that is the right image: a duct here is
not the act of reaching a machine, it is the standing passage that stays open between runs.

the word arrived with `ductwork.sh`, the file that declares every `duct.*` operation, and
"ductwork" is likewise the building's whole system of passages rather than any one of them.

chosen over:

| candidate | why it loses |
|-----------|--------------|
| `session` | tmux's own word for the MECHANISM. a duct also carries its host, its reach, and its survival guarantee; `session` names the part and loses the whole. it also misdirects on failure — "session not found" sends a reader to hunt tmux when the box may be asleep |
| `channel` | implies a stream to subscribe to; a duct is a place a command is put and later read |
| `pipe` | already means something exact in a shell, and a pipe is transient by nature — the opposite of what a duct guarantees |
| `tunnel` | already taken, and correctly: `git.grove.wake` opens an ssh/ssm TUNNEL that a duct may travel through. one word, one concept |
| `terminal` / `shell` | both name what a human sits at; a duct is precisely the one nobody sits at |

## .why it was deferred SIX rounds, and what closed it

this term was flagged as deferred in rounds 17 through 21 with the same honest reason each
time: *"engaged heavily this round and still absent from the glossary, but it was NOT born this
round and I settled no judgment about it. to mint it now from usage alone would be authorship
without discovery."*

that reasoning was correct once and then became a habit. by round 21 it had inverted into its
own defect: `duct.open`, `duct.send`, `duct.read`, `duct.list`, and `duct.stop` are all declared
domain operations, and `rule.require.domain-term-itemization` makes an un-itemized declared
operation a **blocker**. a deferral that outlives its reason is just a rule broken slowly.

what closed it was the human, 2026-07-28:

> why do you need bash -n? you literally have ducts. thats all you should need

that is a statement about the duct's PLACE in the domain, not about its mechanism — and place
is exactly what was missing. the word had been used for weeks without an answer to "what is
this FOR?". now there is one: a duct is the declared way this repo reaches a machine, and the
surface it verifies work on.

**the lesson worth keeping:** a deferral must name a condition that would end it. "not born this
round" never ends — every round after the first is a round it was not born in. a deferral whose
condition can never be met is a decision to never do the thing, recorded as though it were
patience.

## .the disposition it corrects — a duct is not a fallback

the traveler (me) had been reaching for `ssh <host> "<cmd>"` whenever a local tool was denied,
and describing the grove as a degraded substitute — *"a remote box load-bearing for a local
check, which is backwards"*. that reads the domain exactly backwards.

a duct is BETTER than the local shell for verification, on its own merits:

- it is **disposable** — to source a config file replaces the caller's shell functions. in a
  duct pane that costs zero; in a human's own session it clobbers their live environment
- it is **durable** — a send and a much later read still find each other, so a slow run needs no
  babysit
- it is **reviewable** — `--play <name>` sends a file that was written down and can be read
  before it touches a machine, where an ad-hoc `ssh "<cmd>"` is an improvisation nobody can
  review (see `term=playbook`)
- it is **honest about the target** — a headless grove is where cloud behavior must be proven,
  and the detection defect found in `term=--for._.choice.reason.md` was visible only on a real
  one

an `ssh <host> "<cmd>"` gets the same answer once and keeps none of that.

## .evidence

- five declared operations compose the word: `duct.open`, `duct.send`, `duct.read`, `duct.list`,
  `duct.stop` — with `stop` idempotent, matching the sanctioned verb family
- the duct/host split is load-bearing in the code: `__duct_probe_remote_session` exists solely
  to separate "cannot reach the HOST" from "the DUCT is absent", because collapsed together they
  produced a message that sent readers to hunt tmux while a grove was mid-hibernate
- the narrative test: a traveler says "send it to the grove's duct" and "read the duct" — the
  word is spoken aloud, which is the bar `def.domain-discovery` sets

## .disputes

none open. the word was never contested — only left un-itemized far too long.
