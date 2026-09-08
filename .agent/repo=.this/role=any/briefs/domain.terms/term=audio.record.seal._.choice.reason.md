# domain.term.choice.reason: audio.record.seal

## .etymology

from the physical act: a letter is written, then sealed, and only the seal makes it a document
somebody else can trust and carry. the word already carries the two properties this phase has —
it happens **after** the content exists, and it is what makes the content **transferable**.

⇒ the word was already in the code, as a section header (`# 4. seal it`), before it was ever
itemized. this cluster does not coin it; it records what it names and why the alternatives fail.

## .the term was owed by a DEFECT, not by an argument

📜 **2026-09-07.** a 58-minute take was stopped and the human's prompt returned at once with
`💥130`. the summary — duration, size, peak, the `hear it:` line — arrived **76 seconds later**,
after the shell had already redrawn.

the human's read: *"oh dude it just took forever to come through"*.

⇒ the diagnosis needed a word for *the part that had not yet finished*, and the repo had none.
it is not the capture (that had ended), not the take (that is the artifact), and not the run
(that had reported an exit code). it is a **phase with its own lifetime**, and a phase with a
lifetime is a phase a reader must be able to name.

## 🛑 .why `close` is the wrong word, and it is the one a reader reaches for

`close` is what the code's own sidecar field says (`"closed"`), and it reads naturally against
`opened`. it is still wrong for the phase:

| | names | happens |
|---|---|---|
| `close` | the END of capture | the instant `pw-record` returns |
| `seal` | what makes the take readable | for as long as the take is long, AFTER that instant |

⇒ the 76-second gap is exactly the distance between those two words. to call the phase `close`
would name a moment where the truth is an interval — and it is the interval that bites.

⚠️ **the sidecar's `"closed"` field stays as it is.** it records the timestamp at which the take
stopped its growth, which is genuinely a moment. one word may name a field and be wrong for a
phase; the fix is a second word, never a rename of the first.

## .why not `finalize`

it is the word a document pipeline would use, and it imports a promise this domain cannot keep:
**that finalization is a step you may decline.** here there is no such option. a take is sealed,
or it is a file every player reports as empty.

⇒ and it obscures the design's whole point. `audio.record.header.set` exists BECAUSE the seal
can fail to run — a fact `finalize` makes sound like a choice somebody made.

## 🛑 .the cost is NOT where the writes are — measured 2026-09-07

the human asked the sharpest question available: *"how many bytes does it usually save? maybe
we can just skip the seal"*.

⇒ the answer inverted the assumption in this cluster's first draft, which had described the
three acts as peers:

| act | writes | costs |
|---|---|---|
| header repair | **8 bytes** | instant |
| the peak | **0 bytes** | **the entire 76 seconds** |
| the sidecar | ~300 bytes | instant |

**a byte count is the wrong meter for this phase.** to skip the seal saves no storage at all —
it saves time, by the discard of a sidecar, and the sidecar is what makes a take reachable.

⚠️ and the measurement went further than the question: act 1 has been needed **0 of 11 times**,
and two of those takes were killed by a signal mid-capture. so `pw-record` maintains the header
as it streams.

⇒ **that is an argument to keep the act, not to drop it.** its cost is zero and its coverage is
the one failure nobody has yet produced. what it is NOT is the reason the seal is slow — which
is the misread the byte question exposed.

## .the property that makes it worth a term at all

> **the seal is the only phase of a take that can fail with every sample still intact.**

that is unusual enough to be worth a word. every other failure in this family destroys or
prevents samples; a lost seal leaves every sample on disk and merely unreachable, which is why
a repair skill can exist at all.

⇒ so the term marks the one place where the archive's guarantee (*a take survives a crash*) and
the human's experience (*the file reads as empty*) come apart. a reader who has no word for it
will read a zero-length take as a lost take.

## .disputes

### dispute: `close` — raised 2026-09-07 — status: RESOLVED (keep `seal`)
- raised.by  = the mechanic
- claim      = the sidecar already writes `"closed"`, and `open`/`close` is a settled pair in
               this repo (`term=open`, `duct.open`). a third word for the same boundary is
               vocabulary sprawl
- counter    = they name different things, and the difference is measurable at 76 seconds. the
               pair `opened`/`closed` brackets the CAPTURE; the seal is what runs after the
               second bracket. to fuse them would make the sidecar's own two timestamps
               unreadable — `closed` would mean both *"capture ended"* and *"the record is
               complete"*, and on a long take those are over a minute apart
- resolution = keep `seal` for the phase, keep `"closed"` for the field. one word, one concept
               (`rule.forbid.domain-term-ambiguity`)

### dispute: no term at all — raised 2026-09-07 — status: RESOLVED (pave it)
- raised.by  = the mechanic
- claim      = it appears once, as a comment header in one skill. `rule.require.enumerate-before-you-name`
               says one instance cannot pick a word
- counter    = it has three instances, and the rule asks for the enumeration rather than for a
               count: the phase in `audio.record.start`, the standalone repair in
               `audio.record.header.set`, and the `status` a reader tests in
               `audio.record.list`. those are three sites that must agree on what "sealed"
               means, and until now none of them said it
- resolution = pave it. ⚠️ and the honest caveat: the WORD was never contested. what this
               cluster settles is the **boundary** — where capture ends and the seal begins —
               which is what the 76-second measurement made contestable

## .see also
- `term=audio.record.take._.choice._.md` — the artifact a seal makes readable
- `term=open._.choice._.md` — the STATE an unsealed take is left in
- `term=audio.peak._.choice._.md` — the read that makes the seal's cost proportional to the take
- `rule.forbid.failhide` — a prompt that returns before its work is done, reported as complete
