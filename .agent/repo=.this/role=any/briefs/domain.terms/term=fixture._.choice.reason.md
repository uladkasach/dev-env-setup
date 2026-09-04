# domain.term.choice.reason: fixture

## .etymology
in a machine shop a fixture is the jig that HOLDS a workpiece in a known position so a tool
can be judged against it. that is exactly the role here: the play pins a subject into a known
shape, then judges its own reader against it. the workpiece is real; only its placement is
contrived.

`mock` was the near miss, and it is wrong by DIRECTION. a mock replaces a collaborator so the
subject under test can run; a fixture supplies the subject so the collaborator — the reader —
can be judged. to call this a mock inverts which half is real, and the whole value of the move
is that the reader is untouched.

`sample` was declined because it says *representative*, and a fixture is deliberately the
opposite. its arms are the shapes most apt to fool the eye: an id inside an `echo`, a call
whose tool is wrapped, a map-entry shape outside the map it belongs to. a representative arm
would prove the easy case and leave the hazard unmeasured.

`testdata` and `scaffold` were declined as vocabulary borrowed from an adjacent practice. a
fixture here is usually CODE that the reader parses, and it is the measurement rather than its
scenery.

## .disputes
### dispute: exhibit  —  raised 2026-08-14  —  status: RESOLVED (both are kept, as distinct terms)
- raised.by  = the mechanic
- claim      = both are artifacts whose whole job is to settle one question, so one word could
               serve
- counter    = they differ on LIFESPAN, which is the property each term exists to carry.
               `term=exhibit` is *spent the moment its result lands elsewhere* — it still runs,
               and that is what makes it costly, because it reads as coverage. a fixture is the
               opposite: it re-proves its reader on every box, forever, and to delete one is to
               go blind. to merge them would put a permanent clamp in the same bucket as a
               retirement candidate.
- resolution = keep both. an exhibit measures an ARGUMENT once; a fixture clamps a READER
               always.

## .evidence

### what made a fixture mandatory beside a floor — 2026-08-14

two plays went blind on the same day, from one cause, and in both the FLOOR was the only guard:

| play | discovered | declared |
|---|---|---|
| `prove.flathub-apps-serve` | 1 | 4 |
| `prove.registry-packages-serve` | 0 npm specs | 5+ |

both floors fired correctly. neither could say whether the tree had shrunk or the reader had
gone blind — and it was the reader, both times (`term=floor._.choice.reason.md` carries the
measurement).

⇒ so the repair in each was a `direction 0` fixture: one file per declared shape, each with the
verdict the reader must produce — and, in both, an arm per PROSE shape too, since a reader that
finds every declaration and also admits a phantom is wrong in the meaner direction.

### the arm that passed for the wrong reason — the trap this term must name

`prove.offbox-reads-are-bounded` shipped an arm named `_fix_text`, whose stated claim was *"a
tool named inside an echo is prose, not a call."* it passed from the day it was written, and
the reader it described had **no notion of prose at all** — the arm's fixture simply held no
separator, so the tokenizer left the line whole and its first word was `echo`.

the arm was spared incidentally, and an arm spared incidentally is indistinguishable from one
spared on purpose. it stood as the play's stated guarantee for as long as the play existed
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8).

⇒ two disciplines follow, and both are in the say-level file:

1. **each arm names a subject the real tree does NOT declare**, so a `sort -u` cannot collapse
   it onto a true one and hide a false verdict behind a true row
2. **when you change what a reader CLASSIFIES, add an arm for that shape in the same edit** —
   otherwise the play's own direction 0 reports ✔ about a reader that just learned to condemn
   correct code (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.6)

### 🛑 the limit of a fixture — it proves obedience, never truth

the trap above is an arm that passes for the wrong REASON. this one is sharper, and it is
the boundary of what the whole device can do:

> a fixture proves the reader does what you SAID. it cannot prove that what you said is
> true of the tree.

measured 2026-08-14 on `prove.apt-sources-serve`. its new direction 0 shipped an arm named
`a_echoed`, whose stated claim was *"an echoed source line is prose, not a declaration"* —
borrowed, reasonably, from `prove.offbox-reads-are-bounded`, where it is true. it passed on
the first run, and every one of its 14 siblings passed with it.

**it is false here.** an echo piped to `tee` is how every bundle in this tree declares an
apt source:

```sh
echo "deb [signed-by=$keyfile] https://… vscodium main" \
  | sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null
```

so the reader obeyed the arm exactly, and reported **three false ✋** — codium, dropbox,
onepassword — each a bundle that is correct.

⚠️ and the two rows that stayed green did so by luck: `gh` and `docker` guard the write with
`if ! echo …`, so their first word was `if`, not `echo`. a page that showed 4 ✔ and 3 ✋ was
one line of shell away from showing 7 ✋.

⇒ **what caught it was the LIVE half of the same run.** direction 0 said the reader worked;
the rows below said three real subjects had gone dark. neither half alone is a verdict —
the fixture says the eye does as told, the live rows say what it was told was right.

⇒ so a play whose subjects are only ever judged by its own fixture has proven the smaller
claim, and a play that has only live rows cannot tell a broken eye from a shrunken tree
(`term=floor._.choice._.md`). the three devices are a set: **a floor detects, a fixture
attributes, and the live rows are what keep the fixture honest.**

⚠️ the arm is now a PAIR, so neither direction can be asserted without the other —
`a_echo_decl` (an echo piped to `tee` IS a declaration) and `b_echo_prose` (a line sent to
`>&2` is a read-why). a third, `b2_guarded_decl`, holds the `if ! echo` shape whose luck hid
half the defect.

### why a fixture is permanent, and a rollback is not

`rule.forbid.repair-plays` grants exactly two exemptions for a play that writes. a fixture
falls under neither, because it writes only into a temp dir it made and touches no machine
state at all — it is a READ of the play's own reader, dressed as a tree.

⚠️ do not confuse it with `term=play.rollback`, whose four conditions include *deleted when the
bundle it served is proven*. that condition must never be read across: a rollback serves one
experiment, and a fixture re-proves a reader on every box.

## .disputes

### dispute: a fixture's members are its arms — raised 2026-09-02 — status: RESOLVED (arm is its own term)
- raised.by  = mechanic, after a run of `prove.apt-lock-wait-engages` on a grove
- claim      = this file's `## .the ARM` declared *"one member of a fixture is an arm … a fixture
               is its arms."* so every arm belonged to a fixture.
- counter    = false of 3 of the repo's 8 permanent plays, each of which declares arms and no
               fixture at all. and `prove.apt-lock-wait-engages` — the play that surfaced it —
               has arms A and B over the **real dpkg lock**, a live condition it induces. its
               own use of "fixture" names the HOLDER arm B needs, not a set whose members are
               arms.
- resolution = the anchor was inverted. a fixture is one KIND OF SUBJECT an arm may take, and an
               arm is a member of a **direction**. `arm` moved to its own cluster
               (`term=arm._.choice._.md`); this file now cites it and governs the **fixture arm**
               as the special case. dispute closed.

⚠️ the mis-anchor held because it was TRUE of every play in hand when this file was authored —
the pin plays all do build a fixture whose members are arms. a definition is only as wide as its
author's reach, and a term declared as a SUB-SECTION of another inherits that term's anchor with
no reader ever prompted to check it.

## .see also
- `term=arm._.choice._.md` — the member; a fixture is one kind of subject it may take
- `term=floor._.choice._.md` — the partner that detects what a fixture attributes
- `term=probe._.choice._.md` — the near relation that asks the MACHINE rather than the check
- `term=exhibit._.choice._.md` — the artifact a fixture must not be confused with
- `term=bite._.choice.reason.md` — why a check proven in one direction is half proven
