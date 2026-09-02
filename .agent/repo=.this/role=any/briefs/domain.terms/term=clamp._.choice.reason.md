# domain.term.choice.reason: clamp

## .etymology

a **clamp** is a physical thing that holds a part in a fixed position while work happens around
it. three properties of that image carry:

1. **it holds ONE thing.** a clamp grips a specific part. a case that asserts a named property
   is a clamp; a case that asserts "it works" grips no part in particular.
2. **it is only real when it bears load.** a clamp you have never tightened is a clamp you have
   never proven. this is the whole discipline: a case must be seen RED under the defect it
   names, or you own a decoration you believe is protection.
3. **it holds the shape, not the workpiece.** a clamp does not make the part correct — it makes
   the part unable to MOVE. that is exactly the claim a regression case makes: not "this code is
   right", but "this property cannot drift without a loud red".

the verb form (`clamped`, `dogfooded`) is the same word applied to the act. that is ordinary
english, not a second term.

## .disputes

### dispute: test / check / assertion  —  raised 2026-09-02  —  status: RESOLVED (keep `clamp`)

- claim      = `test` is the universal word, understood everywhere, and every case here IS a
               test. `check` and `assertion` are the same idea at finer grain.
- counter    = each is wrong in the direction that matters. `test` carries no obligation to have
               FAILED — a test suite is routinely green from birth, and the industry treats that
               as normal. that permission is precisely what this repo cannot allow: a case that
               has never gone red is indistinguishable from one that exercises no code at all,
               and this file has shipped both (a case whose body scan counted its own comment; a
               case whose form could never reach its target). `clamp` builds the load-bearing
               test into the word — you cannot ask "has this clamp ever held?" and mean no more
               than a shrug by it.
               `check` is worse: it names an inspection that reports, where a clamp REFUSES.
               a check can pass and shrug; a clamp either holds or fails the suite.
               `assertion` names one line, not one property. a clamp is often several lines, and
               occasionally two cases (see `.evidence`), because the property needed both halves.
- resolution = keep `clamp`; record `test`, `check`, `assertion`, `safeguard`, `coverage` as
               forbidden synonyms in contracts. `test` remains legal in a comment that speaks
               about the surrounding tooling (`brains.auth.test.sh` is the harness's own name,
               and the workflow is `test.brains.auth`). dispute closed.

### dispute: guard  —  raised 2026-09-02  —  status: RESOLVED (both survive — distinct concepts)

- claim      = a `guard` also refuses, also holds a property, and this repo already uses the word
               throughout (`the value guard carries real weight here`, the route's `.guard`
               files). one word would serve both.
- counter    = they sit on opposite sides of the artifact. a **guard** is in the PRODUCT — it
               runs in production, refuses a bad input, and its cost is paid by every real
               invocation. a **clamp** is in the SUITE — it never runs in production, and its
               job is to prove a guard (or any other property) still behaves. to merge them
               loses the ability to say the sentence this round needed most: *the bak-integrity
               guard was added, and three clamps prove it refuses.*
               the route's `.guard` file is a third sense again, and it is already load-bearing
               in the driver vocabulary.
- resolution = both stand as separate terms; neither is a forbidden synonym of the other. the
               distinction is product-vs-suite. dispute closed.

## .evidence

the round of 2026-09-02 settled the term by payment of its cost, repeatedly. each item below is
a judgment the word had to be sharp enough to express:

- **a clamp must go red FOR THE REASON CLAIMED, not merely go red.** every case added that round
  was dogfooded by restoration of the defect, and the exact red was recorded:
  `bakverify.short-copy-refuses` → `0|LOST|bak`; `coldstart.no-subs.render-is-pure` →
  `got 'moana@x.com'`; `boot.leaves-no-walk-globals` → `got '_BRAINS_AUTH_BOOTSTRAP_DIR
  _BRAINS_AUTH_WALK '`; `callleaf.usage-ok-survives-caller-pipefail` → `got '3'`.
- **a clamp can be green for the wrong reason, which is the failure the word must name.** one
  case was drafted as `never-reads-zero` and inspected the wrong layer — the coercion happens in
  `_brains_auth_round`, not in the node. it was split into two clamps: one pins the coercion,
  one pins that the gate stops the body before it can reach it. a single case there would have
  read as proof it was not (`hazard.a-clamp-can-lie-the-same-way-code-can.md`).
- **a clamp may legitimately guard the FIX rather than the defect — and must say so.**
  `callleaf.usage-rc-survives-caller-pipefail` cannot bite the defect (under pipefail bash
  reports the rightmost non-zero, so the answer is 7 either way). it is kept, because
  `set +o pipefail` is exactly the kind of repair that could mask a real curl failure — and the
  file states plainly that it guards the repair, rather than let it read as a defect clamp.
- **a FLAKY clamp is a defect report, not noise.** `callleaf.usage-passes-curl-ok` went red with
  `141` roughly one run in three, only under a pipe. that flake WAS the defect: the usage leaf's
  exit code was conditional on the caller's shell options. a word that permits "just re-run it"
  would have lost the find; `clamp` does not, because a clamp that holds only sometimes holds
  no part at all.
- **a clamp counts itself.** `header.count-matches-the-suite` reads the asserted case count out
  of the source preamble and compares it to the suite's own tally, so the `+ 1` in its arithmetic
  is deliberate. it is the clamp on the honesty of the number a reader trusts for a sense of how
  much is clamped.
