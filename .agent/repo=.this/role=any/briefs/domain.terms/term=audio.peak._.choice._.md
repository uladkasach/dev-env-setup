# domain.term: audio.peak

term.chosen   = peak
term.kind     = noun
term.boundary = audio   # a peak is read of a live source AND of a closed take
term.synonyms.forbidden:
- level       # names where a signal sits on average; a peak is the MAXIMUM
- amplitude   # the general quantity; a peak is one statistic OF it
- max         # true and useless — max of what, over what window?
- loudness    # perceptual (EBU R128); a peak is a sample value
- rms         # a DIFFERENT statistic, and the one a human's ear tracks better

## .what

the largest absolute sample value in a span of audio, **always on a 0..32767 scale**.

## 🛑 .the scale is FIXED at 0..32767, whatever width the take was captured at

this is the decision this term exists to hold, and it is not a style choice.

a raw peak is meaningless without its width beside it — **891 of 32767 is a quiet take,
and 891 of 2147483647 is silence.** so a raw sample value would make every threshold, every
sidecar `peak` field, and every row of `audio.record.list` mean a different quantity per
take.

⇒ `__audio_peak_of` scales its read to 0..32767 on the way out. an s32 take's raw peak is
divided by 65536; an s16 take's passes through.

### ⚠️ why it is an ARCHIVE property, not a convenience

📜 **2026-09-07.** the capture format moved from `s16` to `s32`, so this archive now spans
two widths permanently — five takes below the change, every take after it above.

a human asks *"was that one quieter than the last?"* and the answer must hold **across the
change**. a scale that shifts with the format answers that question wrong, forever, on an
archive whose whole purpose is to be read in ten years.

⇒ so the scale is a **contract with every sidecar ever written**, the ones from before the
format moved included. it may not be widened later "now that we have 32 bits" — that would
silently redefine a number already stored on disk.

## .what a peak is read FOR — three claims, one number

| the claim | the test | who asks |
|---|---|---|
| the mic is dead | peak is bit-exact **0** | `audio.record.probe`, the watchdog |
| the take is thin | peak `< 600` | the probe, advisory only |
| the take is clipped | peak `>= 32700` | the meter, advisory only |

⚠️ only the first is a refusal. a quiet room is real, so a thin peak that refused a take
would be a check that cries wolf (`gotcha.a-check-that-cries-wolf-gets-silenced`).

## ⚠️ .a peak is a MAXIMUM, so one thump speaks for a whole window

that is the property to hold in mind when you read one. a single door slam sets the peak of
a minute of quiet speech, where an `rms` over the same window would report the speech. this
repo uses peak anyway, deliberately: the questions above are about **presence and
destruction**, and a maximum answers both. it would be the wrong statistic for a question
about perceived loudness.

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.operations.sh`   # `__audio_peak_of` — the ONE reader
- `.agent/repo=.this/role=any/skills/audio.record.probe.sh`        # dead / thin arms
- `.agent/repo=.this/role=any/skills/audio.record.start.sh`        # the meter, the watchdog, the sidecar
- `.agent/repo=.this/role=any/skills/audio.record.list.sh`         # the `peak` column

## .reason
see the ref-level cluster beside this choice:
- `term=audio.peak._.choice.reason.md` — the etymology, the scale decision, and the disputes
