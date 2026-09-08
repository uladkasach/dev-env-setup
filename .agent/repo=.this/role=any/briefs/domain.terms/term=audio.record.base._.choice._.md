# domain.term: audio.record.base

term.chosen   = base
term.kind     = noun
term.boundary = audio.record
term.synonyms.forbidden:
- baseline    # TAKEN — `term=baseline` is a SET of node versions. see `.reason`
- unity       # the audio-engineer's word; true, and opaque to the human this serves
- max         # false — the knob goes well past it; what ends at the base is the ANALOG gain
- roof        # same falsehood, and it implies a refusal that does not happen
- reference   # names a comparison, not the boundary between two mechanisms

## .what
the capture volume at which a source's ANALOG gain ends and a digital multiply begins.

## 🛑 .why it is the fact that decides a gain answer

below the base, a raise moves the ADC's own amplifier — the voice gets louder and the
noise floor does not, so the take genuinely improves.

at or above it, pipewire multiplies the samples it already has — louder, **identical**
signal-to-noise, and a clipped peak is destroyed with no repair.

⇒ so *"raise the gain"* is good advice under the base and a **trap** above it, and the
volume alone cannot tell the two apart. a check that names a gain fix with no read of
the base is one pattern that serves two opposite correct answers
(`gotcha.a-check-that-cries-wolf-gets-silenced`, q7).

📜 measured 2026-09-06 on this laptop's internal mic — **base 32%, volume 100%**. the
probe's THIN arm printed *"raise it to 140%"*, which named a 4.4× digital multiply and
called it a fix, on a source whose analog gain had been spent three times over.

## ⚠️ .a base is a property of the SOURCE, never of the box

each source declares its own, so a base read off the wrong one is a true number about a
subject nobody asked about (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4). that
error was live in this repo for an hour: an HDMI monitor's `Base Volume: 100%` was
nearly used as the mic's.

⇒ `__audio_source_base_pct` takes the source name for exactly this reason.

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.operations.sh`   # __audio_source_base_pct
- `.agent/repo=.this/role=any/skills/audio.record.source.get.sh`   # the `base:` row
- `.agent/repo=.this/role=any/skills/audio.record.probe.sh`        # the THIN arm reads it

## .reason
see the ref-level cluster beside this choice:
- `term=audio.record.base._.choice.reason.md` — the etymology, the `baseline` collision,
  and the measurement that made the term necessary
