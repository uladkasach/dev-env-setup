# domain.term.choice.reason: audio.gain

## .etymology

adopted from audio engineering, where `gain` has meant *a multiplier applied to a signal*
for as long as there have been amplifiers. the box does not say the word — `pactl` says
`Volume:` — so this is one of the few terms here taken from the craft rather than from the
tool, and the divergence is deliberate (see the `volume` dispute below).

## .the term was owed by a QUESTION, twice

📜 **2026-09-06.** the human asked, of a quiet take:

> *"can we just default reaise it to 150?"*

📜 **2026-09-07.** and then:

> *"are we able to increase the gain afterwards?"* … *"or is there some loss"* …
> *"i just want to get the maximum signal"*

⇒ **the same word, three different quantities, across two days.** the first question meant
the pulse knob at capture; the second meant a multiplier in post. both were answerable and
neither could be answered without a note of WHICH gain, because the honest reply differs:

| the ask | the answer |
|---|---|
| raise the knob to 150% | ✋ no — the base is 32%, so it is already a 3x digital multiply |
| amplify in post | ✔ yes, freely and reversibly — and it improves no part of the take |

that is one word with two opposite verdicts, which is `rule.forbid.domain-term-ambiguity`
met in the wild rather than predicted.

## 🛑 .the finding this term exists to carry — LOUDER is not BETTER

every instinct around a quiet recording reaches for a multiplier, and the reach is correct
for comfort and useless for quality:

- **the SNR is frozen at the converter.** a take that used 10 of its 16 bits holds ~10 bits
  of information. multiply by 33 and it fills all 16 with the same 10 bits of information —
  the voice is 33x louder and so is the hiss, exactly
- **the only gain that improves a take is #1**, and #1 is bounded by the base. past the
  base there is no such gain left to spend
- ⇒ so *"maximum signal"* is not a gain question at all past that point. it is a **distance
  and microphone** question

## .the measurement that ranked the levers

five takes, 2026-09-07:

```
peak 891 · 755 · 725 · 649 · 535     of 32767
loudest = -31 dBFS
```

a voice at conversational distance lands at -12 to -18 dBFS, so this is **13-19 dB low**.

| lever | worth | raises noise with it? |
|---|---|---|
| half the distance to the mic | +6 dB | ✋ **no** |
| a quarter of the distance | +12 dB | ✋ **no** |
| gain #1 (analog) | 0 dB left — spent | — |
| gain #2 or #3 | any amount | ✔ yes, exactly |

⇒ the largest available improvement was the one no command can perform. a glossary that
made all three gains one word would have hidden that, because every reachable answer would
have been a multiplier.

## ⚠️ .the operation this term named, and the name it saved

gain #3 wants a skill. the obvious name was blocked by this repo's own term rules —
`normalize` is a forbidden term (*"overloaded and vague"*), which is the same objection
this cluster raises against `volume`, arrived at independently by a hook.

⇒ so the operation is **`audio.gain.set`**: `set` per `rule.require.get-set-gen-verbs`
(idempotent, overwrites), `gain` per this term. the target is named by a flag
(`--to -1dBFS`, `--by 10x`), never by the verb — because a verb that encodes its target
grows a second verb the first time the target changes.

## .disputes

### dispute: volume — raised 2026-09-07 — status: RESOLVED (keep `gain`)
- raised.by  = the mechanic
- claim      = the box says `Volume:` and `Base Volume:`, so `rule.require.ubiqlang` and
               `rule.forbid.domain-term-inconsistency` both point at the box's word. this
               repo already adopted `base` from that exact output rather than coin `unity`
- counter    = `base` was adopted because it names ONE field with ONE sense. `volume` names
               a knob that spans gain #1 and #2 with the crossover invisible in its own
               output — so to adopt it is to adopt an ambiguity, not a vocabulary. and the
               harm is asymmetric: a reader told *"raise the volume"* cannot tell whether
               they were told to improve the take or to degrade it, and both are one command
- resolution = keep `gain` for the quantity. `volume` stays legal for **that specific pulse
               control** — a read of it, a print of it, the `volume:` row — and may never
               stand in for the quantity. this is the same carve-out `capture` holds under
               `term=audio.record`: the box's word survives where it names the box's field

### dispute: audio.record.gain — raised 2026-09-07 — status: RESOLVED (boundary is `audio`)
- raised.by  = the mechanic
- claim      = `audio.record.base` is boundaried at `audio.record`, and a gain is what a
               base bounds — so the two should sit under one boundary for symmetry
- counter    = **gain #3 applies after the take is closed.** a post amplify reads a finished
               wav and never touches a recorder, so `audio.record.gain` would mis-file a
               third of the term's own sense. `base` is genuinely narrower — it is a
               property of a SOURCE, which only exists at capture
- resolution = `audio.gain`, `audio.record.base`. the asymmetry is real and correct

## .see also
- `term=audio.record.base._.choice._.md` — the point where gain #1 ends and #2 begins
- `term=audio.record.source._.choice._.md` — what a base and a volume are properties OF
- `term=audio.record.take._.choice._.md` — what gain #3 is applied to, on a copy
- `rule.forbid.domain-term-ambiguity` — one word, one sense; the rule this closes
- `gotcha.a-check-that-cries-wolf-gets-silenced` — q7 (one pattern, opposite answers) is
  this term's shape exactly, and the probe's THIN arm was its first casualty
