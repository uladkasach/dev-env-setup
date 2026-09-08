# domain.term.choice.reason: audio.record.take

## .etymology

from film and studio production, where a **take** is one continuous run of the camera or the
recorder — attempt N at a scene, kept whole whether or not it was any good. the word arrived
with three properties this domain needs and did not have to invent:

| the borrowed property | why it fits |
|---|---|
| **one continuous run** | the boundary is a start and a stop, never a duration or a quality bar |
| **an artifact, not an act** | *"we have the take"* names a thing on disk; *"we were recording"* names an act that may have left none |
| **kept even when imperfect** | a thin take, a short take, a cut take are all takes — which is what lets a repair be a repair rather than a rescue |

the third is the one that earns the word here. a vocabulary in which a cut run is not yet a
take would invite the instinct to discard it, and a cut wav holds every second that was
flushed — which for a 90-minute conversation is nearly all of them.

## .the rejected synonyms, and why each fails

| word | why not |
|---|---|
| `recording` | a gerund, forbidden outright (`rule.forbid.gerunds`) — and it names the ACT where the artifact is meant. the two differ exactly when the act produced no artifact, which is the failure this whole family exists to catch |
| `session` | this repo already spends the word three times — a login session, a tmux session, a duct session. a fourth sense is `rule.forbid.domain-term-ambiguity` outright |
| `clip` | presumes a longer whole it was cut from. a take IS the whole; no part was excerpted |
| `capture` | the act. it is the right word for what the probe measures and the wrong one for what the recorder leaves |
| `file` | names one half. a take is a wav and a sidecar, and the word that names the container cannot hold the pair |
| `audio` | the medium. every take is audio; not every audio is a take |

## .disputes

### dispute: does `take` name the PAIR or the WAV — raised 2026-09-06 — status: RESOLVED (the pair; the flag names the body)

- raised.by  = the author, mid-build
- claim      = `--take` is handed a `.wav` path, so `take` must mean the wav. to define it as
               the pair makes the flag name a lie about its own argument.
- counter    = the pair is what a human means. `audio.record.list` reads the sidecar AND the
               wav, and reports a defect that neither half shows alone — the take that ends
               early. define `take` as the wav and there is no word left for the unit that
               reader operates on, so a second word would have to be coined for it. that is
               synonym sprawl by construction.
- resolution = `take` names the **pair**. `--take` names it by its **body**, because the two
               halves are found from each other by name (`<base>.wav` ↔ `<base>.json`), so
               either path identifies the take and the wav is the half that cannot be re-made.
               the say-file states the split explicitly so the flag reads as a choice rather
               than a slip.

⇒ the general shape: where a compound artifact is addressed by one of its parts, name the
**part that cannot be reconstructed**. a sidecar lost costs a title; a wav lost costs the
conversation.

## .evidence

### the boundary is `audio.record`, not `audio`

`rule.require.boundary-qualified-terms`'s test — *"$word, of WHAT?"* — answers *"a take, of a
recorder run"*, and the skill family that owns the run is `audio.record.*`. `audio.take` would
claim the word across playback and mix too, where it has no sense.

### the borrowed metaphor's ONE broken clause, and what it cost

film presumes **take two**. this domain cannot, and the difference is not decorative — it is
the premise every design decision in the family was made against:

| the decision | what it would cost if takes were repeatable |
|---|---|
| the probe runs unconditionally at open | a flag, and a human who forgets it once loses one take of many |
| the recorder streams to disk, never buffers | no cost — a buffer is faster, and a lost buffer is a re-shoot |
| a cut take is repaired rather than discarded | no cost — you would shoot it again |

⇒ recorded here rather than in the say-file's `.what`, because it is the etymology's one
mismatch and a reader who takes the film sense whole will under-build every one of those three.

### measured 2026-09-06 — a take survived a SIGKILL, and the word held

a live take was killed outright at 5m28s / 31.5 MB. its header read `riff: 8 / data: 0` — the
two fields `pw-record` revises only at close — while every flushed second sat on disk.

```
rhx audio.record.header.set --take <wav> --mode apply
rhx audio.record.list
```

recomputed both fields from `wc -c`, and the take read back whole. it was **one take**
throughout — before the kill, after the kill, and after the repair — which is the claim the
`.the unit is the RUN` section makes, measured rather than asserted.
