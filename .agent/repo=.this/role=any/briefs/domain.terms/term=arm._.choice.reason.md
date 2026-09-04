# domain.term.choice.reason: arm

## .etymology

an **arm** is a limb of a whole — it reaches in one direction, and the body is its arms. that is
exactly a play's shape: a measurement reaches toward one claim, and several such reaches together
prove the whole.

chosen over `case` (test-framework vocabulary; it names an INPUT, where an arm carries its wanted
verdict and its reason too), over `assertion` (names only the comparison at the end), and over
`branch` (already means a code path here, and a play runs every arm rather than one of them).

the word arrived by use rather than by declaration — it sits in 8 of this repo's permanent plays
and in `define.cry-wolf-measurements` 32 times. that is why it was mis-anchored for so long: a
word nobody declares is a word nobody checks the anchor of.

## .disputes

### dispute: arm belongs to `fixture` — raised 2026-09-02 — status: RESOLVED (arm is its own term)
- raised.by  = mechanic, after a run of `prove.apt-lock-wait-engages` on a grove
- claim      = `arm` was declared inside `term=fixture._.choice._.md`, under `## .the ARM`, as
               *"one member of a fixture … a fixture is its arms."* so a play's arms are, by that
               declaration, always members of a fixture.
- counter    = three of this repo's eight permanent plays declare arms and **no fixture at all**
               (`prove.nvim-fetches-no-unpinned-plugin`, `prove.kitty-signature-binds-the-pin`,
               `prove.reply-captures-bypass-the-runner`). and the play that surfaced it,
               `prove.apt-lock-wait-engages`, has arms A and B whose subject is the **real dpkg
               lock** — a live condition it induces, never a file it wrote. its word "fixture"
               refers to the HOLDER that arm B needs, not to a set whose members are arms.

               ⇒ the anchor is inverted. a fixture is one KIND OF SUBJECT an arm may take; it is
               not the whole an arm is a member of. an arm is a member of a **direction**.
- resolution = `arm` gets its own cluster, anchored on the play's measurement rather than on
               `fixture`. `term=fixture` keeps its `direction 0` convention and now CITES `arm`
               rather than declares it. dispute closed.

## .evidence

measured 2026-09-02 across `.play/permanent/`:

```
plays that declare arms:      8
plays that declare a fixture: 6
arms with NO fixture:         3   ← the refutation
```

⚠️ **the mis-anchor was invisible for the ordinary reason: it was TRUE of every play the author
had in hand.** `term=fixture` was authored while the pin plays were the live subject, and every
one of those does build a fixture whose members are arms. the sentence generalized from a
correct sample — which is `gotcha.a-check-that-cries-wolf-gets-silenced` q11 in vocabulary
rather than in code: **a definition is only as wide as the reader's reach at the moment it was
written down.**

⇒ the corollary for the glossary: a term declared as a SUB-SECTION of another term inherits that
term's anchor silently. `arm` sat under `## .the ARM` inside `fixture`, so no reader ever asked
whether its anchor was right — the file it lived in had already answered.

## .the live-arm obligation this surfaced

`prove.apt-lock-wait-engages` also settled what a **live** arm owes beyond a fixture arm. its
arm B holds the real `/var/lib/dpkg/lock-frontend`, and it does three things a fixture arm has no
need of:

1. **arm A doubles as the fixture read for arm B** — if some other process already holds the
   lock, arm B could not attribute its own wait to its own holder, so the play exits 2 rather
   than claim a verdict
2. **it polls `fuser` until the hold takes**, and declines if it never does
3. **it judges the restore by a RE-READ of the lock**, never by the exit code of the kill

each is the same rule in a different costume: **a live arm must read its subject back, because
its world can fail to become what the arm assumes.** that obligation is now stated in the say
file, where the author of the next live arm will meet it.
