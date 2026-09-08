# domain.term.choice.reason: audio.peak

## .etymology

adopted from audio engineering, where *peak* has always named the maximum instantaneous
amplitude, as against *rms* for the averaged one. the pair is old, standard, and taught —
so the word was never a choice, and the cluster exists for the SCALE rather than the noun.

## .the arrears, and what finally forced it

📜 **2026-09-06.** `peak` was already in `__audio_peak_of`, in every sidecar, in three
skills' output, and in three named thresholds — and it was **not itemized**. round 5's
progress file recorded it as *"the next term owed"* and deferred it, because `gain` was the
term the human's question had settled.

📜 **2026-09-07.** the deferral ended, and not on a schedule: the capture format moved from
`s16` to `s32`, which forced a **decision about what the number means**. an unstated
convention became a stated contract the same hour it could first be broken.

⇒ that is the honest shape of this arrears. the word did not need a cluster while one
format existed, because the scale was implicit and unambiguous. the second format is what
made it a claim somebody could get wrong.

## 🛑 .the decision — and the two ways it could have gone

when a take can be 16-bit or 32-bit, `peak` has two defensible definitions:

| | raw sample value | scaled to 0..32767 |
|---|---|---|
| an s16 take's quiet voice | 891 | 891 |
| an s32 take's **identical** voice | 58,392,576 | 891 |
| comparable across the archive? | ✋ **no** | ✔ yes |
| needs a width beside it to mean anything? | ✔ yes | ✋ no |
| the three thresholds still hold? | ✋ each needs a per-width variant | ✔ unchanged |

⇒ **scaled wins on the property that outlives us.** the raw form is more faithful to the
file and less useful to a human, and this archive exists to be read by a human in ten
years.

### the cost, stated plainly

the scaled form **discards resolution** — an s32 peak is divided by 65536, so the bottom 16
bits of the measurement are dropped. that is a real loss and it is the right trade: a peak
is read to answer three coarse questions (dead / thin / clipped), and no one of them turns
on a distinction finer than 1/32767.

⚠️ if a future question ever needs the raw value — a true-peak analysis, an inter-sample
overshoot — it must be a **new reader with a new name**, never a widened `peak`. the number
in every sidecar already written is on this scale, and to redefine it would make a stored
record mean something it did not mean when it was stored.

## .the near-miss the format change nearly caused

the same hour, `__audio_seconds_of` computed duration with a hardcoded `* 2` bytes per
sample. left alone, an s32 take would have reported **half its true duration** — a wrong
number, in range, with no error. its sibling `__audio_peak_of` would have read misaligned
bytes and returned **a plausible peak with no signal in it**.

⇒ both are `rule.forbid.failhide` at its quietest: not a crash, not a `✋`, just a
believable number that is wrong. the repair was to make every reader ask **the take's own
header** rather than the config (`term=declared` / `term=live` — the config is the declared
half, the file is the live one).

⇒ and the one legitimate exception is worth its own note: `audio.record.start` reads the
DECLARED width, because at that moment the take does not exist yet and we are the party
about to determine it. `__audio_bytes_per_sample_declared` exists so that caller cannot be
confused for the others.

## .disputes

### dispute: rms — raised 2026-09-07 — status: RESOLVED (keep `peak`)
- raised.by  = the mechanic
- claim      = an ear tracks average energy far better than instantaneous maxima, so `rms`
               would report "how loud does this sound" — which is what a human actually
               asks of a take
- counter    = it is the wrong statistic for all three questions this repo asks. **dead**
               needs a maximum: an rms over a window with one click is non-zero, so a dead
               mic with a single glitch would read alive. **clipped** needs a maximum by
               definition — clipping is a property of individual samples, and an rms cannot
               see it at all. only **thin** would be better served, and thin is advisory
- resolution = keep `peak`. an `rms` reader may be added later for a loudness question, and
               it would be a **new term beside this one**, never a redefinition of it

### dispute: a 0.0..1.0 float scale — raised 2026-09-07 — status: RESOLVED (keep 0..32767)
- raised.by  = the mechanic
- claim      = a float 0..1 is width-agnostic by construction and needs no magic constant,
               so it states the intent more honestly than a number borrowed from s16
- counter    = three facts. (1) **every sidecar already written holds an integer on this
               scale** — a change would redefine stored data. (2) bash has no float
               arithmetic, so every threshold comparison would route through `awk`, which
               adds a process to the meter's twice-a-second loop. (3) `32767` is legible to
               anybody who has met 16-bit audio, where `0.0272` is legible to nobody
- resolution = keep `0..32767`. the scale is admittedly a borrowed one, and it is borrowed
               from the format this archive began in — which is the correct anchor for an
               archive that must stay self-consistent

## .see also
- `term=audio.gain._.choice._.md` — what a peak is raised BY, and why that changes no ratio
- `term=audio.record.take._.choice._.md` — the artifact whose sidecar carries a `peak`
- `term=declared._.choice._.md` · `term=live._.choice._.md` — the split that decides whether
  a reader asks the config or the file
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why thin and clip are advisory
- `rule.forbid.failhide` — the shape a mis-scaled peak would have taken
