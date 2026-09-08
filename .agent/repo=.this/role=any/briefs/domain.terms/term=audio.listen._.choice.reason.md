# domain.term.choice.reason: audio.listen

## .etymology

the human's ask, 2026-09-06, verbatim:

> *"plz create an audio.listen operation which takes a path to an audio and opens the
> cosmic audio reader"*

⇒ the word arrived **named**. `listen` was not chosen from a shortlist; it was the word
a human reached for while they described what they wanted, which is the strongest
etymology a term can have (`howto.domain-discovery`, move 1 — adopt the expert's word,
never translate it).

what this record adds is the **check** that the given word survives: does it collide,
does it overload, does it claim more than the operation delivers.

## .the collision it survived

`play` is the obvious english verb and it is **taken**, hard:

| the word | what this repo already means by it |
|---|---|
| `play` | a multi-step command in a reviewed file, run by `rhx play.run` |
| `play.prove` / `play.verify` / `play.await` / `play.rollback` | its four sub-verbs |

so `audio.play` is not a near-miss — it is a second sense for a word that already heads
a four-member family, and a family whose members are governed by
`rule.forbid.repair-plays` because **some of them write to a machine**.

⇒ the cost of that overload is not confusion, it is a **misread of a contract**: a
reader who knows `play` and meets `audio.play` brings a write-capable mental model to a
read-only skill.

⚠️ the human's given word dodged this collision by luck, not by design — they were not
asked to check the glossary. that is exactly why an arrived word is still checked.

## .disputes

### dispute: audio.record.play — raised 2026-09-06 — status: RESOLVED (keep `listen`)
- raised.by  = the mechanic, mid-authorship
- claim      = the `play` collision is a NAMESPACE problem, and this repo already solves
               namespace problems with a boundary (`rule.require.boundary-qualified-terms`).
               so `audio.record.play` is the cheap fix: it keeps the plainest english verb,
               it disambiguates from a bare `play`, and it needs no new word at all
- counter    = the boundary fixes the collision and introduces two defects of its own —
               1. **it parses two ways.** to an ear `audio.record.play` says "play what
                  was captured". to a reader of this glossary it says "the `play` sub-verb
                  of the `audio.record` family", by exact analogy with `play.prove` and
                  `grove.push`. one string, two parses, and both are plausible
               2. **the boundary is FALSE.** `audio.record.*` is the capture side — it
                  opens a source, probes a mic, repairs a header. this operation touches
                  none of that; it runs against a closed take, potentially years later,
                  and needs no mic at all. to file it under `record` claims a kinship the
                  code does not have, and the next reader inherits that claim
- resolution = keep `listen`, at boundary `audio` rather than `audio.record`. record
               `play` as a forbidden synonym so a future author who reaches for it finds
               this entry rather than re-derives the collision

### dispute: playback — raised 2026-09-06 — status: RESOLVED (keep `listen`)
- raised.by  = the mechanic
- claim      = `playback` is the domain's own noun for the event, it carries no collision
               with `term=play`, and the probe's own `--play` flag already speaks it
- counter    = it is a **noun**, and this is a `[verb][...noun]` operation
               (`rule.require.treestruct`). `audio.playback` names the event; it does not
               name the act a human asks a machine to perform. and the near-miss is the
               hazard: `playback` shares a prefix with the forbidden `play`, so a reader
               who skims sees the collision anyway
- resolution = keep `listen`. `playback` stays legal in **prose** to name the event —
               the forbid governs contracts (`rule.forbid.domain-term-synonyms`)

## .evidence

### the operation delivers what the word promises, and no more

`listen` was checked against what the code can actually claim. the skill:

- hands the file to the desktop's declared handler and returns
- **cannot** know whether a window appeared, whether an app was installed, or whether a
  human heard a sound

⇒ so the term names the HAND-OFF. this is `term=live`'s split applied to a verb: a
command may judge what it MEASURES and may not judge a consequence it merely set in
motion. the skill states the gap in its own output rather than let the verb imply it
away (`rule.forbid.failhide`).

### the `--with cli` arm does NOT change the word

`--with cli` runs `paplay` in the foreground, so on that arm the skill genuinely holds
the playback for its duration. that is a stronger claim than the desktop arm makes —
and it does **not** earn a second verb, because a human's ask is the same in both cases.
the flag names the CARRIER; the verb names the ask.

⚠️ this is the reverse of what `term=audio.record.take` settled, where one word had to be
checked against two parts of a compound artifact. here two mechanisms answer one ask,
and a verb per mechanism would be the ambiguity `rule.forbid.domain-term-synonyms`
forbids.

## .see also
- `term=play._.choice._.md` — the collision, and the family it heads
- `term=audio.record.take._.choice._.md` — the artifact this verb operates on
- `term=audio.record.source._.choice._.md` — the capture-side peer, at a different boundary
- `term=live._.choice._.md` — the measure-vs-consequence split this verb obeys
- `rule.forbid.domain-term-ambiguity` — the rule `audio.play` would have broken
