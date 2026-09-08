# domain.term: audio.gain

term.chosen   = gain
term.kind     = noun
term.boundary = audio   # NOT `audio.record` — post gain applies after a take is closed
term.synonyms.forbidden:
- volume      # names the KNOB pulse exposes, which is one gain of three. see below
- amplify     # a verb for the act; this term names the quantity
- boost       # informal, and it implies improvement — the exact false promise below
- level       # names WHERE a signal sits, never how much was applied to it
- loudness    # a perceptual measure (EBU R128), not a multiplier

## .what

a multiplier applied to a signal.

## 🛑 .the term exists because ONE word names THREE quantities, and they differ in the only way that matters

| # | gain | applied | raises noise? | improves SNR? |
|---|---|---|---|---|
| 1 | **analog** | before the converter | ✋ no | ✔ **yes** |
| 2 | **digital, at capture** | after the converter, live | ✔ yes, equally | ✋ no |
| 3 | **post** | after the take is closed | ✔ yes, equally | ✋ no |

⇒ **only #1 buys a better take.** #2 and #3 make a take LOUDER and change no part of what
it holds — the ratio of voice to hiss was frozen the instant the converter sampled it.

⚠️ so *"raise the gain"* is an ambiguous instruction, and the two readings have opposite
value. that is `rule.forbid.domain-term-ambiguity`, and it is why every use of this word in
this repo must be qualified by WHICH of the three.

## .the boundary between #1 and #2 is the BASE, and the box states it

`term=audio.record.base` names the point where analog gain ends. below it, a raise is #1;
above it, the identical knob silently becomes #2 — same command, opposite worth.

📜 measured on this laptop, 2026-09-06: **base 32%, volume 100%.** so the analog gain was
already spent 3x over, and every further percent had been #2 the whole time.

## ⚠️ .why `volume` is forbidden, and it is NOT a style call

`pactl` says `Volume:` and `Base Volume:`, so the word is the box's. it is forbidden as a
SYNONYM here because it names one knob that spans two of the three senses, with the
crossover invisible in its own output. a reader told *"raise the volume"* cannot tell
whether they were told to improve the take or to degrade it.

⇒ `volume` stays legal where it names **that specific pulse control** — a read of it, a
print of it, the `volume:` row in `audio.record.source.get`. it may never stand in for this
term.

## 🛑 .the fourth lever that is NOT gain, and outranks all three

**distance.** sound pressure falls ~6 dB each time the distance doubles, so half the
distance is +6 dB of **signal** with no rise in the mic's self-noise.

📜 measured 2026-09-07: five takes peaked at 891/755/725/649/535 of 32767 — the loudest at
**-31 dBFS**, where a voice at conversational distance lands at -12 to -18. that **13-19 dB**
is not a gain deficit and no gain can repay it; #1 was spent, and #2 and #3 raise the hiss
along with it.

⇒ **when a take is quiet, read the distance before the gain.** the lever with 18 dB behind
it is physical, and it is the one this whole family of words cannot reach.

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.probe.sh`       # branches THIN on the base
- `.agent/repo=.this/role=any/skills/audio.record.source.get.sh`  # prints `volume:` + `base:`

## .reason
see the ref-level cluster beside this choice:
- `term=audio.gain._.choice.reason.md` — the etymology, the measurements, and the disputes
