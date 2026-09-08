# domain.term: audio.record

term.chosen   = record
term.kind     = verb   # ⚠️ VERB ONLY. the noun sense is forbidden here — see below
term.boundary = audio
term.synonyms.forbidden:
- capture     # legal in PROSE, forbidden in an operation name — see `.the one carve-out`
- tape        # names a medium this repo has never touched
- log         # taken repo-wide, and it means a text trail
- track       # names one CHANNEL of audio, which is a different concept entirely
- session     # names the human's hour, never the act; and pulse already owns the word

## .what

commit sound to disk as it happens.

## 🛑 .the overload this term exists to CLOSE — `record` is a verb here, never a noun

ordinary english gives `record` two senses, and they are exactly opposite in direction:

| sense | means | example |
|---|---|---|
| **verb** ✔ | to capture | *"record the conversation"* |
| **noun** ✋ | the artifact captured | *"play the record"* |

⇒ **this repo declares the verb and forbids the noun.** the artifact has its own word:
`term=audio.record.take` — a *take*.

so the family reads one way only:

```
audio.record.start     # start to record          ✔ verb
audio.record.list      # list what you recorded   ✔ verb, and it lists TAKES
audio.record.probe     # probe before you record  ✔ verb
audio.listen           # hear a take back         ✔ — and NOT under audio.record
```

## .why the noun had to be forbidden rather than left ambiguous

📜 **2026-09-06.** the noun sense was live, unstated, and it cost a skill its name. a human
read `audio.record.open` and reported:

> *"open sounds like listen"*

⇒ parse `record` as a **noun** and the command says *"open the audio record"* — which is
precisely `audio.listen`'s job. the misread was not a slip; it was the second legal parse
of a name that had two.

the repair took two moves, and the second is this term:

1. the ACT was renamed to `audio.record.start`, which removes the one member where the two
   parses collided with a live peer operation (`term=start`)
2. the noun sense is now **forbidden outright**, which removes the collision everywhere
   else it could recur — `audio.record.list` and `audio.record.probe` carried the same
   double parse and nobody had read them yet

⚠️ **move 1 alone would have masked the defect.** the rename fixed one name; the overload
was upstream of the verb and would have surfaced again at the next member added. this is
`rule.require.solve-at-cause` — the cause is the word, not the one command that showed it.

## ⚠️ .the one carve-out — `capture` in prose

the operation names say `record`. **prose may say `capture`**, and does:

```
🎙️ audio.record.start — capture a take, straight into the dir that backs it up
```

⇒ that is not drift. `capture` names the OUTCOME of a whole take, where `record` names the
act while it runs — so a help line about what a human gets is right to use it, and an
operation name about what the command does is right to refuse it
(`term=start._.choice.reason.md` carries the dispute).

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.start.sh`
- `.agent/repo=.this/role=any/skills/audio.record.list.sh`
- `.agent/repo=.this/role=any/skills/audio.record.probe.sh`
- `.agent/repo=.this/role=any/skills/audio.record.header.set.sh`
- `.agent/repo=.this/role=any/skills/audio.record.source.get.sh`

## .reason
see the ref-level cluster beside this choice:
- `term=audio.record._.choice.reason.md` — the etymology, and the noun/verb dispute
