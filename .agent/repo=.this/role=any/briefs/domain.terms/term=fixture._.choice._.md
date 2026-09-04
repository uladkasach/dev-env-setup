# domain.term: fixture

term.chosen   = fixture
term.kind     = noun
term.synonyms.forbidden:
- mock         (a mock stands in for a COLLABORATOR at run time. a fixture is the SUBJECT, and
                the reader it is fed to is the real one — the opposite arrangement)
- stub         (same defect: it names a replaced dependency, never a supplied subject)
- sample       (says representative. a fixture is chosen to be EXTREME — the shape most apt to
                fool the reader, not the shape most often met)
- testdata     (test-framework vocabulary, and it says data where a fixture is usually CODE the
                reader must parse)
- scaffold     (names setup that enables a run. a fixture IS the measurement, not its scenery)
- probe        (already itemized, and it asks the MACHINE a question — `term=probe`)
- exhibit      (already itemized, and it is SPENT once its result lands elsewhere. a fixture is
                permanent and re-runs forever — `term=exhibit`)

## .what
a synthetic subject a play builds so it can ask a question of its own **reader**: one file per
shape the reader must classify, each paired with the verdict it must produce and the reason
that verdict is right.

```
── direction 0: the reader finds each declared shape, and spares prose
   ✔ org.probe.WrappedInstall — find  (the web_ boundary — half the blindness, verbatim)
   ✔ org.probe.EchoProse      — skip  (an id inside an echo is a human's read-why, not a call)
```

## .the ARM — its own term, and NOT a member of a fixture
an **arm** is one member of a play's measurement in one direction: one subject, one wanted
verdict, one reason (`term=arm._.choice._.md`).

🛑 **a fixture is one KIND OF SUBJECT an arm may take, never the whole an arm belongs to.**
📜 the inverse is measurably false: 3 of the repo's 8 permanent plays declare arms with no
fixture anywhere in the file. the dated dispute and its measurement sit in
`term=fixture._.choice.reason.md`.

⇒ so a **fixture arm** is the special case this file governs: its subject is a file the play
wrote, whose right verdict it knows. a **live arm** takes a condition the play induces or finds,
and owes one more duty — it must read its subject back, since its world can fail to take.

## .the direction it belongs to
a play's numbered sections are its **directions**. a fixture over the play's own reader takes
`direction 0` by convention: it must hold before any later direction's rows read as evidence.

## 🛑 .a probe asks the MACHINE; a fixture asks the CHECK
the split that keeps both words:

| | its subject | what it is built from |
|---|---|---|
| **probe** | the box | a question the box can answer |
| **fixture** | the play's own reader | files the play wrote, whose right verdict it knows |

a play with probes and no fixture proves the box and never proves its own eye.

## .the pair with FLOOR
> **the floor detects; the fixture attributes.** a play that discovers its own subjects owes
> both, and neither substitutes for the other (`term=floor._.choice._.md`).

## 🛑 .a fixture proves OBEDIENCE, never TRUTH
it proves the reader does what you SAID. it cannot prove what you said is true of the tree — so
an arm may encode a false claim about the domain, pass, and certify a defect.

⇒ the live rows are the third member: **a floor detects, a fixture attributes, and the live
rows keep the fixture honest.** measured 2026-08-14, when a borrowed arm turned three correct
bundles red while its 14 siblings all went green beside it
(`term=fixture._.choice.reason.md`).

## ⚠️ .an arm may pass for the WRONG REASON
an arm that would still pass with the property it names absent proves no part of that
property. so each arm carries a subject the real tree does NOT declare — otherwise a `sort -u`
collapses the arm onto a true subject and the row goes green either way
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

## 🛑 .an arm may be a WORLD rather than a TEXT — and then it can fail to TAKE
every fixture above writes files whose TEXT a reader parses, so an arm either matches or does
not. an arm may instead build a **world** — a `$HOME`, a checkout shape, a registry entry —
which adds a second way to be wrong that no verdict can show: **the setup may not take.**

⇒ measured 2026-08-13 (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.5): a probe redirected
`$HOME` and only HALF the world followed, because `$HOME` is not a sandbox — it moves the
readers that consult the variable and not the ones that consult the passwd database. every row
was true, and the verdict described a world nobody meant to create.

so a world-shaped arm owes one more line than a text-shaped one: **read back what the subject
OBSERVED**, never merely that it ran. `prove.helper-finds-a-pushed-checkout` parses the chosen
repo out of the helper's own decline text, so an arm that failed to take reports the wrong path
rather than a confident verdict.

## 🛑 .a SHARED reader owes its own fixture, and owes it hardest
a reader read by one play may hold its fixture inside that play. a reader read by THREE cannot:
whichever caller held it would be the only one that proved it, and the other two would rest on a
claim their own page never states (`rule.require.seam-claims-have-an-owner`).

⚠️ and a shared reader with **no** fixture is worse than three copies of it. three copies drift,
and a drift at least shows up as a disagreement; one shared blind spot is uniform across every
caller, and uniform is invisible.

⇒ so `_.tree-reads.lib.sh` — read by the three pin plays — carries its fixture in a play of its
own, and that play's `direction 3` strips each property the reader claims and demands the arms
REFUSE the result. an arm that would still pass with its property absent proves no part of it
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

## .reason
see the ref-level cluster beside this choice:
- `term=fixture._.choice.reason.md` — etymology, why `mock` and `sample` were declined, and the
  measurement that made a fixture mandatory beside a floor
