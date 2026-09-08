# domain.term: audio.listen

term.chosen   = listen
term.kind     = verb
term.boundary = audio
term.synonyms.forbidden:
- play        # TAKEN — `term=play` is a grove play, a reviewed command file. see `.reason`
- playback    # a noun for the event; this term names the ACT a human asks for
- hear        # names what the human's ear does, which no command can promise
- audition    # a judgment of a candidate; a take is already chosen
- preview     # implies a partial or lower-fidelity read; this hands over the whole take
- open        # TAKEN — `term=open` is the STATE a live take is in, which a finished
              #   take is not. and the human read `audio.record.open` as playback once
              #   already, which is the misread that cost that skill its name

## .what
hand a finished take to a player, so a human can hear it back.

## 🛑 .why NOT `play`, and why that is not a preference

`play` is a **declared noun in this repo** — a multi-step command written down as a
reviewed file, run by `rhx play.run` and by `git.grove.send --play`
(`term=play._.choice._.md`). an `audio.play` skill would put one word on two concepts
in one namespace, which is `rule.forbid.domain-term-ambiguity` outright.

⚠️ and the collision is not cosmetic — it lands on the **most dangerous** neighbour.
`play` is the word this repo uses for a thing that TOUCHES A MACHINE, bounded by
`rule.forbid.repair-plays`. a reader who sees `audio.play` and reaches for what they
know of plays reads a write where there is a read.

## ⚠️ .why `listen` rather than a qualified `play`

`audio.record.play` would disambiguate by boundary and still be wrong twice:

1. it reads as *"play a recording"* to an ear and *"the play sub-verb of the record
   family"* to a reader of this glossary. one string, two parses
2. it is **not part of the record family**. this skill runs against a take that is
   closed, days or years later. `audio.record.*` is what the capture side owns

⇒ so the boundary is `audio`, not `audio.record`, and the verb is the human's own word
for the act: they do not *play* a story, they *listen* to it.

## .what it does NOT claim

`listen` names the HAND-OFF, never the hearing. this skill launches a player and
returns; whether a window appeared and whether a human heard anything is beyond any
exit code it could produce. its own output says so in as many words.

⇒ that is the same split `term=live` carries — a command may judge what it MEASURES
and may not judge a consequence it merely set in motion.

## .refs
- `.agent/repo=.this/role=any/skills/audio.listen.sh`                 # the operation
- `.agent/repo=.this/role=any/skills/audio.record.operations.sh`      # __audio_player_declared, __audio_opener_get

## .reason
see the ref-level cluster beside this choice:
- `term=audio.listen._.choice.reason.md` — the etymology, the `play` collision, the
  resolved `audio.record.play` dispute
