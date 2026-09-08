# domain.term.choice.reason: audio.record

## .etymology

adopted from the box and from the craft at once. `pw-record` is the binary this family
drives, `pactl` calls a mic a *source* that one records from, and every human who has ever
pressed a red circle has met the verb. the word was never a choice.

⇒ so what this cluster adds is not the word. it is the **half of the word we refuse** —
the noun — and the reason that refusal is load-bear rather than pedantic.

## 🛑 .the term was owed by a MEASUREMENT, not by a naming round

📜 **2026-09-06.** a human read a command line and reported:

> *"should this say audio.record.start? instead of open? open sounds like listen;
> rhx audio.record.open --purpose demo"*

the obvious read is that `open` is the defective word, and a dispute was opened on exactly
that (`term=open._.choice.reason.md`). the counter-argument found a **sharper cause one
level up**:

- read `record` as a **verb**: *"open, in order to record audio"* → the capture command ✔
- read `record` as a **noun**: *"open the audio record"* → the playback command ✋

⇒ both parses are grammatical. the name had two senses, so the misread was not a human
error at all — it was the name, correctly parsed, along its other branch.

⚠️ and the noun parse was **not confined to the one skill that showed it**:

```
audio.record.list      # "list the audio records"  → sounds like a library index
audio.record.probe     # "probe the audio record"  → sounds like an inspect-a-file command
```

both of those were live, both read wrong under the noun, and neither had drawn a complaint
— because nobody had needed to run them beside an `audio.listen` yet.

## .why the rename alone was not the repair

the human ruled `audio.record.start`, and that was correct: it removed the one member where
the two parses collided with a live peer operation. but a rename fixes a NAME, and the
defect was in a WORD.

| repair | what it closes | what it leaves |
|---|---|---|
| rename `open` → `start` | the one collision a human hit | the noun parse, in every other member |
| **forbid the noun** | the parse itself | none — the artifact already had `take` |

⇒ `rule.require.solve-at-cause`. and the second column is the one that matters for the next
member added to this family: without the forbid, the next author names it under a word with
two senses and re-earns the same complaint.

## .the artifact already had its own word, which is what made the forbid cheap

`term=audio.record.take` was itemized on the same day, for the same family. so the noun
sense of `record` was not a concept in want of a home — it was a **second word for a
concept that already had one**, which is `rule.forbid.domain-term-inconsistency` rather
than a gap.

⇒ that is the whole reason this forbid costs no capability. a forbid on a noun with no
replacement would be a hole; a forbid on a noun whose concept is already named `take` is a
tidy-up.

## .disputes

### dispute: capture — raised 2026-09-06 — status: RESOLVED (keep `record`, carve out prose)
- raised.by  = the mechanic
- claim      = `capture` has one sense only. it never parses as a noun for the artifact, so
               `audio.capture.start` would close the overload by construction rather than by
               a declared forbid a reader must first find
- counter    = three facts against. (1) the box says `record` — `pw-record` is the binary,
               and to rename would put this repo's word beside the tool's, which is
               `rule.forbid.domain-term-inconsistency` against the wider domain
               (`rule.require.ubiqlang`). (2) `capture` names the OUTCOME of a whole take;
               `record` names the act while it runs — so `audio.capture.probe` would claim
               to probe a finished artifact. (3) the forbid is not a weaker fix: a reader
               who parses `record` as a noun and greps for the word finds this file, where a
               reader of `capture` finds no record of why the obvious word was passed over
- resolution = keep `record` for every OPERATION name. `capture` stays legal in **prose**,
               where it earns its keep in one sentence — *"capture a take"* — because there
               it names what the human ends up with

### dispute: audio.take — raised 2026-09-06 — status: RESOLVED (keep `audio.record`)
- raised.by  = the mechanic
- claim      = the family's artifact is a `take`, so `audio.take.start` would put the noun
               where a noun belongs and drop the contested verb entirely
- counter    = it names the wrong subject. `audio.record.probe` probes the MIC, and
               `audio.record.source.get` reads a SOURCE — neither touches a take, so a
               `take`-headed family would mis-file two of its five members. the boundary is
               the ACT of recording, and the take is one artifact that act produces
- resolution = keep `audio.record`. the take keeps its own cluster
               (`term=audio.record.take`), correctly nested under the act that makes it

## .see also
- `term=audio.record.take._.choice._.md` — the noun the forbid points at
- `term=start._.choice._.md` · `.reason.md` — the rename that surfaced this, and the
  lesson it carries about a defense that enumerates
- `term=open._.choice.reason.md` — the dispute where this cause was first named
- `term=audio.listen._.choice._.md` — the operation the noun parse collided with
- `rule.forbid.domain-term-ambiguity` — one word, one sense; the rule this closes
- `rule.require.solve-at-cause` — why the rename alone was not the repair
