# domain.term.choice.reason: open

## .etymology

`open` entered this repo through `duct.open` — a tmux session opened toward a grove — and
was reused by `term.open` and `audio.record.open` without argument, because each does the
same act: put a resource live and leave it live.

⚠️ **it was never itemized**, and the arrears is the point of this file. three skills
spoke the word for months; a human then asked whether the audio one should say `start`
instead, and there was no glossary entry to answer from. an unnamed convention cannot be
conformed to — it can only be guessed at.

⇒ the trigger to write it down was the DISPUTE, not the coinage. that is late but not
wrong: a word earns a cluster the hour somebody argues with it.

## .disputes

### dispute: start — raised 2026-09-06 — status: RESOLVED (`start` prevails, as a NEW term)
- raised.by  = the human, verbatim:

  > *"should this say audio.record.start? instead of open? open sounds like listen;
  > rhx audio.record.open --purpose demo"*

- claim      = `open` reads as "open a file to view or hear it", the ordinary desktop
               sense, so `audio.record.open` invites the exact misread that `audio.listen`
               now performs. `start` cannot be read as playback under any parse, so it
               removes the ambiguity outright

- counter    = three facts pull the other way, and one of them is inside the artifact —

  1. **the take answers with the word.** `audio.record.open` writes `"status": "open"`
     into the sidecar, and `audio.record.list` reads it back to tell a live take from a
     cut one. so `open` names a STATE the code stores, not merely the moment it began. a
     verb called `start` beside a state called `open` is one concept under two words in
     one file — `rule.forbid.domain-term-inconsistency` in miniature

  2. **it is a three-member family.** `duct.open`, `term.open`, `audio.record.open` all
     mean *put a resource live and leave it live*. a rename of one member declares two
     words for one act across the repo, and the drift is silent — each name reads fine
     alone

  3. **the misread is SELF-CORRECTING, and cheap.** a human who runs
     `audio.record.open` in hope of playback sees a 3-second mic probe and
     `● live — ctrl-c to stop` before any harm. cost: three seconds, no lost take. the
     inconsistency in 1 and 2 costs a permanent second word, silently, forever

- ⚠️ what the counter does NOT dispute: **the misread is real and was measured.** a human
  read the command and reported the wrong sense. that is evidence, and this entry exists
  so it is not lost to a defense of the status quo.

  ⇒ and the counter names a **sharper cause** than the one the claim names. the word that
  parses two ways is not `open`, it is **`record`**: as a verb it means *to capture*, as a
  noun it means *the artifact captured*. read `record` as a noun and `audio.record.open`
  says "open the audio record" — which is exactly `audio.listen`'s job. so the ambiguity
  is upstream of the verb, and `start` would mask it rather than settle it: the noun sense
  of `record` stays available in every other member of the family
  (`audio.record.list`, `audio.record.probe`) whatever this one is called

- resolution = **`start` prevails, and becomes a term of its own.** the human ruled,
               verbatim:

  > *"audio.record.start instead"*

  ⇒ `audio.record.open` → `audio.record.start`. `duct.open` and `term.open` are untouched,
  and `"status": "open"` stays the state word in the sidecar — so the two words now split
  cleanly (`term=start._.choice._.md`).

  this is the second outcome `howto.domain-term-disputes` names: *the disputed word
  prevails → it becomes a new term of its own, a distinct concept.*

## 🛑 .what the counter got wrong — it proved the SPLIT and then argued against it

the counter's own first sentence was:

> *"`start` names an INSTANT. `open` names the state that instant produces."*

that is not an argument for one word. **it is the enumeration that proves there are two
concepts**, and the counter read it as a reason to make one word carry both — which is
`rule.forbid.domain-term-ambiguity` verbatim: one word, two senses.

⇒ the tell was available in the counter's own strongest fact. it wrote that a rename would
leave *"the verb called `start` and the state called `open`"* and called that an
inconsistency. it is not. an act and the state it produces are **supposed** to have two
words — `stop`/`stopped`, `wake`/`awake`, `push`/`pushed`. the inconsistency it feared is
the ordinary shape of a verb beside its adjective.

⚠️ and the third counter-point — *"the misread is SELF-CORRECTING, and cheap"* — measured
the wrong cost. it priced the human's THREE SECONDS and never priced the read: a word that
must be corrected on every encounter is a tax on every future reader, and only the first
one is cheap. `def.ergonomic`'s *unambiguous* line is exactly this: a label may read one
way only, and *"a result that invites a re-read"* already fails, whatever the recovery
costs.

⇒ the general lesson, and it is the reusable half: **when a counter-argument names the two
senses out loud in order to defend one word, it has already answered the question against
itself.** `rule.require.enumerate-before-you-name` asks for the list of instances before
the word; here the list existed, inside the defense, and was not read as a list.

## ⚠️ .what the counter got RIGHT, and which survives

the `record` noun/verb overload is real and is **not** settled by this rename. read
`record` as a noun and `audio.record.list` still says *"list the audio records"*. the
rename removed the one member where the overload collided with a live peer operation
(`audio.listen`); it removed no overload.

⇒ itemized in its own cluster: `term=audio.record._.choice._.md`.

## .evidence

### the family, measured 2026-09-06 — BEFORE the rename

```
.agent/repo=.this/role=any/skills/duct.open.sh
.agent/repo=.this/role=any/skills/term.open.sh
.agent/repo=.this/role=any/skills/audio.record.open.sh    # → audio.record.start.sh
```

### the state, in the artifact the act writes

`audio.record.start.sh` — the sidecar it emits at the start of a take:

```
"opened": "<stamp>",
"status": "open",
```

and `audio.record.list.sh` reads that exact string back:

```
elif [[ "$status" == "open" && "$drift" -eq 0 ]]; then
```

⇒ **this tie is why the rename stopped at the skill name.** the two skills must agree on
the stored string, and a rename of it would make every take captured before today read as
an unknown status. the act moved to `start`; the state did not move at all, and
`audio.record.start.sh` carries a 🛑 block at the write site so no later reader "finishes
the rename".

⇒ it was also the counter's strongest fact, and it was checkable rather than argued —
which is why it survived the dispute intact while the two arguments beside it did not.

## .see also
- `term=audio.listen._.choice._.md` — the operation whose sense the claim says `open` steals
- `term=audio.record.take._.choice._.md` — the artifact whose sidecar carries `status: open`
- `rule.forbid.domain-term-inconsistency` — one concept, one word, even before a canon exists
- `rule.forbid.domain-term-ambiguity` — one word, one sense; what the `record` noun/verb
  overload would break if it were ever itemized
- `howto.domain-term-disputes` — the pattern this entry follows
