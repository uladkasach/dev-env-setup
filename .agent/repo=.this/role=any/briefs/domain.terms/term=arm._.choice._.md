# domain.term: arm

term.chosen   = arm
term.kind     = noun
term.synonyms.forbidden:
- case         (test-framework vocabulary, and it says one INPUT. an arm is an input paired with
                the verdict it must produce and the reason that verdict is right)
- scenario     (says a story. an arm is one measurement in one direction, not a narrative)
- assertion    (names the comparison at the end. an arm is the whole limb — subject, wanted
                verdict, reason — and the comparison is its last line)
- branch       (already means a code path here, and a play's arms are not alternatives; a play
                runs every arm it declares)
- leg          (a bare synonym: it carries no sense `arm` lacks, so it buys only drift)

## .what
one member of a play's measurement in a single direction: **one subject, one wanted verdict,
one reason that verdict is right.** a play states its arms and runs every one.

```
   ├─ arms
   │  ├─ A. lock free  ✔ returned in 0s, stayed silent
   │  ├─ B. lock held  ✔ waited 15s, announced both edges
   │  └─ restore     ✔ /var/lib/dpkg/lock-frontend is free again
```

## 🛑 .an arm's subject may be a FIXTURE, and often is not

this is the split the word turns on, and the one it was declared on the wrong side of until
2026-09-02 (`term=fixture._.choice.reason.md`, the dated dispute):

| the arm's subject | example |
|---|---|
| a **fixture** — a file the play wrote, whose right verdict it knows | `direction 0` of the pin plays |
| a **live** condition the play induces | `prove.apt-lock-wait-engages` holds the real dpkg lock |
| a **live** condition the play merely finds | a `rack` entry, a port, a tracked path |

⇒ **a fixture is a KIND OF SUBJECT an arm may take, never the thing an arm is a member of.**
measured across `.play/permanent/`: 8 plays declare arms, 6 declare a fixture, and **3 declare
arms with no fixture anywhere in the file.**

## .what every arm owes, whatever its subject

1. **a wanted verdict, stated before the run** — an arm that reads its own result and calls that
   the expectation proves no claim (`rule.forbid.failhide`)
2. **a reason** — why that verdict is the right one, so a later reader can judge the arm itself
3. **teeth** — it must go red with the property absent. an arm that would pass either way proves
   no part of what it names (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8)

## ⚠️ .an arm whose subject is LIVE owes a fourth thing: read the subject back

a fixture arm either matches its text or does not. a **live** arm has a second way to be wrong
that no verdict can show: **the condition may not take.** so it reads the world back before it
measures against it.

`prove.apt-lock-wait-engages` is the worked example — arm B holds the real lock, then polls
`fuser` until it confirms the hold took, and **declines** rather than report a verdict about a
world it failed to build (`gotcha.a-check-that-cries-wolf-gets-silenced`, q5).

## ⚠️ .`armed` / `disarmed` is a DIFFERENT word, and it is not this one

`3.3.desktop` speaks of a keybind as **armed** (it does work) or **disarmed** (rewritten to
`true`, a no-op). that is an adjective about a CONTROL; this term is a noun about a play's
measurement. one english root, two parts of speech, two contexts that never meet.

⇒ recorded here rather than forbidden, because the keybind sense predates this term and is
the right word there. what a reader must not do is read `the LockScreen action is ARMED ✔`
as a claim about a play arm.

## .the direction it sits in
a play's numbered sections are its **directions**; arms are the members of one direction. so
the nesting is: play → direction → arm. `term=fixture` owns the `direction 0` convention.

## .refs
- `.play/permanent/prove.apt-lock-wait-engages.play.sh` — arms A/B over a LIVE lock, no fixture
- `.play/permanent/prove.nvim-fetches-no-unpinned-plugin.play.sh` — 23 arm mentions, no fixture
- `.play/permanent/prove.every-bundle-is-dispatched.play.sh` — arms over a fixture
- `term=fixture._.choice._.md` — one kind of subject an arm may take

## .reason
see the ref-level cluster beside this choice:
- `term=arm._.choice.reason.md` — etymology, the dispute that split it from `fixture`
