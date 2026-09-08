# domain.term: audio.record.seal

term.chosen   = seal
term.kind     = verb
term.boundary = audio.record
term.synonyms.forbidden:
- close      # names the END of capture; a seal happens AFTER capture ends
- finalize   # implies an option to not finalize; a take is sealed or it is damaged
- finish     # names the whole run, not the phase
- save       # the bytes were already on disk before the seal ran
- flush      # names a buffer write; the seal writes no audio at all

## .what

what turns a **captured** take into a **readable** one: repair the wav header, measure the
take, and write the sidecar that names it `done`.

⇒ the seal writes **not one byte of audio**. every sample was already on disk when it began.
what it writes is the record that makes those samples reachable, playable, and comparable.

## 🛑 .the three acts — and ONE of them is why the phase exists

the axis that separates them is not what each act writes, nor what it costs. **it is what is
unrecoverable if it never runs.**

| act | if the seal never runs | |
|---|---|---|
| 1. repair the header's two size fields | `pw-record` maintains them live, and `audio.record.header.set` runs it later by hand | **recoverable, twice over** |
| 2. read duration + peak off the artifact | both are pure functions of the bytes on disk — `audio.record.list` can compute either, any time | **recoverable — a CACHE** |
| 3. write the sidecar with `"status": "done"` | 🛑 no read of a finished wav can say whether it ended deliberately or was cut short | **UNRECOVERABLE** |

⇒ **the seal exists for act 3. acts 1 and 2 ride along because they are free.**

⚠️ that is not a case to delete them. act 1 costs 8 bytes and covers the one failure nobody has
produced; act 2 is free HERE (the watchdog already read those bytes) and a full scan per row
anywhere else. **"recoverable" prices an act; it does not condemn it.** what it condemns is a
design that presents three acts as equals when one carries the phase.

### .why act 3 cannot be derived — the property that earns this term

a complete take and a cut take are **the same kind of file**. both are valid wavs, both play,
both carry correct headers. the difference is not IN the file; it is a fact about how the file
stopped, and only the process that stopped can record it.

⇒ so for an archive whose takes cannot be re-made, act 3 answers the one question a reader in
ten years has no other way to ask: **did the recorder die, or did the story end?**

### 📜 all three are instant — and that was NOT always true

act 2 cost ~1 min per hour of take until 2026-09-07 (below). every design that treated the seal
as slow — a *"one second…"* message, a detach, a `do NOT close this window` warn — was a
workaround for a cost that no longer exists.

### 📜 act 2 cost ~1 min per HOUR of take until 2026-09-07

it called `__audio_peak_of` over the whole file: an hour of s32 mono is ~690 MB and ~168
million samples through `od` into `awk`. on a 58-minute take that was **76 seconds**.

⇒ the repair was at cause (`rule.require.solve-at-cause`): `__audio_watch` was **already** at
that file every 60s to test for silence, and threw each result away. it now keeps the max and
writes `<max> <seen>` beside it, so the seal folds that with a scan of the tail alone — a range
bounded by the tick interval rather than by the take.

⚠️ **the tail scan is not optional, and it is what keeps the number honest.** a watchdog can
die early, so its max covers a PREFIX. to return it alone would be `rule.forbid.failhide` — a
take whose loud half came after the death would read as quiet, in range, with no signal.
`prove.audio-peak-seal-covers-the-take` plants the loud audio past `seen` and demands the seal
still find it.

### 📜 act 1 has never once been needed — measured 2026-09-07

every take this archive holds, planned through `audio.record.header.set`:

| takes | header already correct |
|---|---|
| 9 scratch | 9 ✔ |
| 2 archive, one of them 58 minutes | 2 ✔ |

⚠️ **two of those were killed by a SIGNAL mid-capture** and their headers were still exact. so
`pw-record` keeps the two size fields current as it streams — it does not write them on exit.

⇒ the repair is **insurance that has not yet paid out**, and it is kept for that reason rather
than retired: the one case it exists for (a kill so abrupt the last write is lost) is the case
nobody has produced, and an unrepeatable take is the wrong place to find out.

## 🛑 .a take can EXIST and be UNSEALED — that is the whole design

`pw-record` streams into the file as it goes, so a crash, a kill, or a lost battery leaves a
complete take with a header that claims zero length. **the take survives; the seal does not.**

⇒ that is why `audio.record.header.set` is a separate skill a human can run by hand. it exists
to perform the seal's first act, later, on a take whose seal never ran.

⇒ and it is why the sidecar carries `"status"` rather than the filename: an unsealed take keeps
its name and reads as `open` (`term=open._.choice._.md`), so no rename can be lost.

## ⚠️ .the seal has its OWN lifetime — short now, and still its OWN

the seal is sub-second, so a human no longer waits on it. what has NOT changed is that it is a
**separate event from the prompt's return**, and the two can still part company: the seal runs
inside a shell whose `rhx` wrapper dies on ctrl-c, so the prompt redraws first and the seal
finishes after it.

⇒ **judge a take by its sidecar, never by the moment the prompt came back.** the gap is now
milliseconds rather than a minute, and it is a gap all the same.

## 🛑 .the LISTEN line is the first thing the seal prints, and that is load-bear

📜 2026-09-07: on the 58-minute take the human waited out the whole 76 seconds, and what they
were waiting for was one line — `hear it: rhx audio.listen --take '…'`. it needs one variable
this skill has held since before the take began, and it costs zero to print. it was last.

⇒ so the defect was never only that the peak was slow. **a zero-cost line a human needs was
sequenced behind the most expensive act in the skill**, and that ordering is wrong at any
speed. the fix for the cost and the fix for the order are separate, and both were owed.

⇒ the rule it yields: **within a phase, the cheapest act a human came for goes first.** every
number the seal prints is a claim about bytes; only the listen settles whether the take holds
what they meant to keep, so it must not queue behind the ones that cannot.

## .refs
- `.agent/repo=.this/role=any/skills/audio.record.start.sh`       # the seal phase, step 4
- `.agent/repo=.this/role=any/skills/audio.record.operations.sh`  # `__audio_peak_sealed`
- `.agent/repo=.this/role=any/skills/audio.record.header.set.sh`  # the seal's first act, alone
- `.agent/repo=.this/role=any/skills/audio.record.list.sh`        # reads what the seal wrote
- `.play/permanent/prove.audio-peak-seal-covers-the-take.play.sh` # the clamp on act 2

## .reason
see the ref-level cluster beside this choice:
- `term=audio.record.seal._.choice.reason.md` — the etymology, the lifetime measurement, and
  the disputes
