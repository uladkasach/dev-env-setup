# domain.term: plant

term.chosen   = plant
term.kind     = noun + verb
term.synonyms.forbidden:
- fixture      (already itemized, and it is the OPPOSITE arrangement: a fixture is SYNTHETIC,
                built by the play. a plant goes into the LIVE subject — `term=fixture`)
- arm          (already itemized as one MEMBER of a fixture. an arm is synthetic too, so it
                inherits its author's blind spot; a plant is what escapes that)
- probe        (already itemized, and its subject is the BOX. a plant's subject is the READER
                — `term=probe`)
- canary       (says a passive sentinel that waits for harm. a plant is an ACTIVE break, made
                on purpose, and removed by the same hand)
- mutant       (mutation-test vocabulary. it names a machine that perturbs code at scale; a
                plant is one deliberate row, chosen for the shape a reader may not see)
- seed         (says a row meant to GROW and stay. a plant is removed in the same session)
- decoy        (says a row meant to mislead. a plant is meant to be CAUGHT — a plant nobody
                catches is the whole result)

## .what
one deliberate violation written into the **live subject** so a check can be seen to redden on
it, then removed in the same session.

it is the only device that answers *"can this reader see the shape my corpus is actually
written in?"* — because a fixture can only hold a shape its author already sees.

## 🛑 .the four devices, and what each can answer

| device | its subject | it answers |
|---|---|---|
| **floor** | the set the reader discovered | did the set SHRINK? |
| **fixture** | synthetic files the play wrote | does the reader OBEY its stated claim? |
| **live rows** | the real corpus, read passively | is that claim TRUE of the tree? |
| **plant** | the real corpus, written on purpose | can the reader SEE this shape at all? |

⇒ the first three all rest on what their author could imagine. the plant is the one that can
refute a **blind spot**, because the corpus supplies the shape and the author supplies only
the defect.

## ⚠️ .a plant is a WRITE, and it is bounded

`rule.forbid.repair-plays` EXCEPTION 2 permits it: a round trip whose net effect is zero. so a
plant carries four obligations, and each is load-bear:

1. it goes into the **live** subject — a plant into a fixture is an arm, and proves less
2. it is **removed in the same session**, and the removal is VERIFIED (a re-read of the byte
   count, plus a grep for the marker — never a claim that it was removed)
3. it is **minimal**, so exactly one check can see it. a broad break reddens several and
   implicates none
4. it carries an inline marker that says it is a plant and must come out

## 🛑 .what a plant refutes — a NULL result read as a NEGATIVE one

a check that has produced only green verdicts has been **half proven**, never disproven
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`). the temptation is to read a
run of `0` verdicts as evidence that the reader is blind. it is not — it is the absence of
evidence, and the plant is what converts it into either direction.

⇒ measured 2026-08-30 on the `bhrain` prose reviewer. three green runs — an empty set, an
87-line rule, and a 1502-line brief — produced a `🛑` claim that *"the reader does not
discriminate"*, supported by a fall in output tokens (898 → 337) as the subject grew 17×.

**two plants refuted it.** the same two files, one ramble each, returned `1 blocker 🔴` at
1.2k tokens AND at 21k, with output at 1,800 and 4,578. the reader cited the rule by name and
gave the line range.

⚠️ so the token metric was the trap: **output tokens track what a reader FOUND, not how hard it
looked.** a wrong read is most dangerous when it arrives with a number attached
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7).

## .refs
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.12 declares the device and the reason a
  fixture cannot substitute; its `.the test` q11 is the question a plant answers
- `rule.forbid.repair-plays` — EXCEPTION 2, the write this term is permitted under
- `term=fixture._.choice._.md` — the synthetic twin, and the `floor` / `fixture` / `live rows`
  trio a plant completes
- `term=bite._.choice._.md` — what a plant is run to observe
- `term=probe._.choice._.md` — the device whose subject is the box rather than a reader

## .reason
see the ref-level cluster beside this choice:
- `term=plant._.choice.reason.md` — etymology, the `graft` dispute, and why the word was taken
  from m.12's prose rather than coined fresh
