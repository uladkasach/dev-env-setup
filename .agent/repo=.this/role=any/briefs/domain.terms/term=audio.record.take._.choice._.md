# domain.term: audio.record.take

term.chosen   = take
term.kind     = noun
term.boundary = audio.record
term.synonyms.forbidden:
- recording    (a gerund — `rule.forbid.gerunds`; and it names the ACT, where the artifact is meant)
- session      (overloaded three ways here already: a login, a tmux pane, a duct)
- clip         (implies an excerpt CUT from a longer run; a take is whole by construction)
- capture      (the act, not its artifact — a take is what a capture leaves behind)
- file         (names the container and loses the sidecar, which is half the record)
- audio        (the medium, not the unit)

## .what
one continuous run of the recorder — opened once, closed once, and whatever it holds in
between. it is the unit a human names, reads back, and keeps.

## .the unit is the RUN, never the duration
a take is bounded by a start and a stop, and by no other measure. a 4-second probe and a
90-minute conversation are each exactly one take. so a take that ends early is still one
take, and never a partial one — which is why a cut take is repaired rather than discarded
(`audio.record.header.set`).

## 🛑 .a take is a PAIR, and `--take` names it by its body

| half | holds | if lost |
|---|---|---|
| the wav | the pcm — what the room said | ✋ the conversation, and it cannot be re-made |
| the sidecar json | what a human declared (purpose, title) + what the recorder measured at close | 🌙 a title, which a human can re-supply |

⇒ so `--take` takes the **wav** path, though the take is both. the flag names the
irreplaceable half, and the sidecar is found beside it by name.

⚠️ and the two are read TOGETHER, never one alone: the sidecar carries what was declared and
the wav carries what is on disk this instant. they disagree exactly when a take was cut, so a
read of either alone reports a take that ends early as healthy (`rule.forbid.failhide`).
`audio.record.list` is the reader that holds both.

## ⚠️ .where the borrowed word breaks

`take` is film and studio vocabulary, and there it presumes **take two**. that is the one
clause this domain does not inherit: a take here is a conversation with a person, so there is
no second one.

⇒ the whole shape of this family follows from that single break — the probe runs
unconditionally before a take starts, the recorder streams to disk rather than buffers, and a
crash is designed to cost seconds rather than the take.

## .refs
- .agent/repo=.this/role=any/skills/audio.record.start.sh       # starts one, and leaves it OPEN
- .agent/repo=.this/role=any/skills/audio.record.list.sh        # reads them back, both halves
- .agent/repo=.this/role=any/skills/audio.record.header.set.sh  # `--take <wav>`, repairs a cut one
- .agent/repo=.this/role=any/skills/audio.record.probe.sh       # proves one will capture sound

## .reason
see the ref-level cluster beside this choice:
- `term=audio.record.take._.choice.reason.md` — etymology, the rejected synonyms, and the
  pair-vs-body dispute
