# domain.term.choice.reason: audio.record.base

## .etymology

adopted from the box, not coined. `pactl list sources` declares the field itself:

```
Base Volume: 21038 /  32% / -30.00 dB
```

⇒ so `base` is what pulseaudio and pipewire already call it, and every human who has
ever read that output has met the word there. to rename it would be a translation of the
domain's own vocabulary, which `howto.domain-discovery` forbids in its first move.

what this term adds is not the word — it is the **SENSE**, written down. the box states
a number and says none of what the number decides.

## .the collision it had to survive

`baseline` is already a declared term here, and it is a **different concept**:

| term | what it names |
|---|---|
| `baseline` | the SET of node versions a box carries beside its default |
| `audio.record.base` | the POINT on one volume knob where analog gain ends |

a set versus a point; a provision concern versus an audio one. they share five letters
and no sense.

⇒ so this term is boundary-qualified (`rule.require.boundary-qualified-terms`) and
`baseline` is recorded as forbidden — a future author who writes *"the mic's baseline"*
finds this entry rather than the node one.

## .why the term was owed at all — the measurement

📜 **2026-09-06.** the human asked, of a quiet take:

> *"can we just default reaise it to 150?"*

a reasonable ask, and the answer turns entirely on a fact no reader had consulted.
measured on this laptop's internal mic:

```
   ├─ volume:  100%
   ├─ base:    32% — ⚠️ 100% is ABOVE it, so 68% of this is
   │           a digital multiply. it raises noise with signal, and clips
```

so 150% would have been a **4.7× digital multiply** on an unrepeatable take: louder
hiss, identical voice, real clip risk. the gain had been spent three times over before
the question was asked.

### what the absent term had already cost

`audio.record.probe`'s THIN arm printed, on that same box:

```
· then, if it is still thin, raise the capture gain from 100%:
    pactl set-source-volume '<source>' 140%
```

a **specific, plausible, authoritative** instruction to make the take worse. that is the
false-✋ shape `gotcha.a-check-that-cries-wolf-gets-silenced` names in q7: one pattern
(*"the peak is low"*) that serves two situations whose correct advice is opposite, told
apart only by a fact the reader never consulted.

⇒ the repair was not a better sentence. it was to **read the base** and let the arm
branch on it. a term exists so the next author knows there is a fact to read.

## .the near-miss worth recording

the base was almost read off the **wrong source**. `pactl list sources` emits a block per
source, and the first `Base Volume:` in that output belonged to an HDMI monitor:

```
Base Volume: 65536 / 100% / 0.00 dB
```

100% — which would have said *"the gain is untouched, raise away"*, the exact opposite of
the truth, from a true line of real output.

⇒ that is `gotcha.a-check-that-cries-wolf-gets-silenced` m.4 in miniature: correct
evidence, wrong subject. it is why `__audio_source_base_pct` takes the source name and
tracks block membership with an `inblock` flag rather than take the first match.

## .disputes

### dispute: unity — raised 2026-09-06 — status: RESOLVED (keep `base`)
- raised.by  = the mechanic
- claim      = *unity gain* is the precise audio-engineering term for the point where a
               stage neither amplifies nor attenuates, and the probe's own prose already
               says *"at unity"* in one arm
- counter    = the box does not say `unity`, it says `Base Volume`. so a human who reads
               `pactl` output and a human who reads this repo would hold two words for
               one field — `rule.forbid.domain-term-inconsistency`. and the audience is
               a person who wants their grandmother's voice recorded, not a mixdown
               engineer: `base` is legible without the craft
- resolution = keep `base`. `unity` stays legal in **prose**, where it earns its keep in
               one specific sentence — *"at unity, a raise past here is a digital
               multiply"* — because it names WHY the point matters

### dispute: max — raised 2026-09-06 — status: RESOLVED (keep `base`)
- raised.by  = the mechanic
- claim      = to a human, "the max useful volume" is exactly what the number means, and
               it needs no explanation at all
- counter    = it is **false**, and falsely reassuring in the dangerous direction. the
               knob does not stop at the base — it goes to 150% and beyond, and every
               percent past the base still gets louder. a human told `max: 32%` who then
               successfully sets 100% concludes the tool was wrong, and stops trusting it
- resolution = keep `base`. what ends at the base is the ANALOG gain, not the range, and
               the term must not claim a limit the box does not enforce

## .see also
- `term=baseline._.choice._.md` — the near-neighbour it must never be confused with
- `term=audio.record.source._.choice._.md` — what a base is a property OF
- `term=declared._.choice._.md` — a base is DECLARED state, read from the box, never measured
- `gotcha.a-check-that-cries-wolf-gets-silenced` — q7 (one pattern, opposite answers) and
  m.4 (right evidence, wrong subject), both of which this term closes
