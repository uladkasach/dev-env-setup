# domain.term.choice.reason: bite

## .etymology

from the mechanical sense — a brake bites, a bolt bites, a clamp bites. the shared
picture is a part that **engages and takes hold**, against one that sits there,
moves, and grips no part of what it touches.

that is exactly the failure the word names here. a check that runs, prints, exits 0,
and could never have exited otherwise is a brake that moves without contact: every
outward sign of a live part, and no force transmitted.

`bite` beat the candidates because each of those names the check's ACTIVITY, and
what deserves a word is its **power to refuse**.

## .why the rejected words lose

| word | why it fails |
|---|---|
| `work` | a check that always says ✔ "works" by any ordinary reading. the word cannot distinguish the defect from the healthy case, which is the whole job |
| `pass` | names the green direction — the half that proves the least. "the check passed" is compatible with a check that cannot fail |
| `catch` | implies a defect was really there. an INTENTIONAL break proves a bite, so "catch" makes the routine case sound like an incident |
| `fire` / `trigger` | say the check produced output. a check that prints a wrong verdict fired perfectly |
| `validate` | what the check does on every run, healthy or not. it names the function, not the property |
| `enforce` | the RULE enforces; the check is the instrument. "a check enforces" borrows the rule's authority for a mechanism that may sit inert |
| `assert` | names what the code does. `bite` names whether that assert is reachable in the false direction at all |

## .the two claims the word keeps apart

these are why the term earns a file rather than a gloss:

```
"the pin holds"   → a fact about the ARTIFACT: what upstream serves matches
"the pin bites"   → a fact about the CHECK:    a tampered artifact is refused
```

a play that reports only the first has proven that today's bytes are the expected
bytes. it proves **not one thing** about what happens to unexpected ones — the case
the check exists for.

📜 measured across this repo's pin plays: every one tests the second direction
explicitly, and each does so because a reader once mistook the first direction alone
for proof.

## .the shape a bite takes in a play

three arms, and the middle one is the bite:

```
✔ what upstream serves today matches the pinned digest    ← it HOLDS
✔ refused a one-byte tamper                               ← it BITES
✔ refused an absent file                                  ← it BITES (a second way)
```

and, where several checks share a family, a fourth arm proves each guards **its
own** subject — a cross-pair sweep, so a pin that matched every artifact gets caught
(`prove.sha256-pins-bite`, direction 3: 56 cross-pairs over 8 subjects).

⚠️ and a fifth question sits behind all four, learned 2026-08-13: **is the SET of
subjects itself proven?** that play named its 8 subjects in a hardcoded list of 6
for weeks, so two pinned downloads bit in neither direction — nobody asked them. a
check can bite perfectly and cover the wrong set, and a green page looks identical
either way (`gotcha.grepsafe-glob-goes-quiet`).

### ⚠️ the set has TWO ways to be wrong, and the second one goes GREEN

the paragraph above covers a set too SMALL — a real subject nobody asked about. the
repair DISCOVERS the set from the tree rather than lists it. that repair opens the
opposite hole, measured the same day on `prove.registry-packages-serve`:

> a discovered set can be too LARGE, and every phantom in it reports **✔**.

its first run read this line, which is an `echo` inside a bundle's verify:

```
echo "      ⇒ a global 'pnpm install -g rhachet' pulls in none of its optional" >&2
```

and asked npm about `pulls`, `in`, `none`, `of`, `its`, `optional`. **five of those
are real npm packages**, so five ✔ rows printed for subjects the tree never
installs — beside one ✋ for `>&2`, which is what made anyone look.

| the set is… | how it reads | how it is found |
|---|---|---|
| too small | a clean page, one row short | a floor guard, or a coverage arm |
| too large | a clean page, **padded with green** | only by a read of the rows themselves |

⇒ the too-large case is the meaner one. a missed subject at least leaves the count
suspiciously low; a phantom subject makes the count look BETTER, so it flatters the
very number a reader uses to judge coverage. and had every phantom been an
unpublished word, the play would have gone red and earned a "fix" by skip-list — a
repair aimed at a defect that was never in the tree.

⇒ so a discovery must match a **declaration**, never a mention. prose that quotes a
command is documentation, and a play that reads it as a fact confuses the map for
the territory (`rule.require.judge-declared-state-not-live-state`). anchor the match
at the head of the line, and read the discovered list once with your own eyes before
you trust the tally.

### ⚠️ a FLOOR names that the set shrank, and never why — measured 2026-08-14

the table above credits a floor guard with the too-small case. true, and not enough.
`prove.flathub-apps-serve` discovered **one** id where four are declared. the floor
fired, correctly, and said this and no more:

```
✋ discovered only 1 flatpak app id(s); at least 4 are declared
```

which leaves a reader with two candidate causes and no way to rank them:

| the cause | the repair |
|---|---|
| a bundle dropped three apps | none — the play is right, and should be re-floored |
| the play's eye went blind | fix the reader, and the tree was fine all along |

it was the second. two edits had landed between the reader and its subject, and
**neither touched the play**: `src/grove.web.sh`'s boundary renamed the call to
`web_flatpak install`, and the three ids moved out of a `for` loop in an upsert and
into a `declare -gA` map in `_.sh` (`gotcha.a-check-that-cries-wolf-gets-silenced`,
m.2 — a third file changes the SHAPE of the text between a reader and its subject).

⚠️ **the first of those two instructs most, because it did no harm.**
`web_flatpak install` still holds the text `flatpak install`, so that half still
answered. the reader did not die — it **degraded**, and a reader that fails PARTWAY
reads as a subject that shrank rather than as a broken eye. a total failure surfaces
the same hour; a partial one gets argued with.

⇒ so the repair is a **fixture over the reader itself** — a `direction 0` that hands
it one file per declared shape and demands the right verdict on each. its prose arms
name ids the real tree does NOT declare, so no arm can pass by collapse onto a true
one (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.8: an arm that passes
incidentally is indistinguishable from one that passes on purpose).

⇒ and the FLOOR tells you to go read direction 0. the two are a pair: the floor
detects, the fixture attributes. neither substitutes for the other, and a play that
discovers its own subjects owes both. the same day, the identical shape turned up
and closed in `prove.registry-packages-serve`, whose anchor had gone blind to
`web_pnpm install` and to `corepack` in one stroke.

⇒ both halves of that pair are itemized, and each carries the full measurement:
`term=floor._.choice._.md` and `term=fixture._.choice._.md`.

## .the boundary a dispute drew — a GUARANTEE does not bite, it engages

### dispute: `bite`, for a guarantee — raised 2026-09-02 — status: RESOLVED (keep `bite` narrow)
- claim      = a wait proven in both of its directions had earned the word, so
               `prove.apt-lock-wait-bites` was a correct name.
- counter    = this file's own invariant refuses it: *a `prove.*-bites` play that
               exercises only the green direction is misnamed*. `pkg_await_apt_lock`
               returns 0 in EVERY branch, by design — the caller is the check — so it
               has no red direction to exercise. its arms are `engaged` and `stood
               aside`, and neither is a verdict.
- resolution = `bite` keeps its scope. `engage` was born for the other axis, and the
               play was renamed `prove.apt-lock-wait-engages`.

⚠️ the two are one metaphor split in half, which is why the drift is easy: a brake
**bites** (grip against resistance — it CAN refuse), a clutch **engages** (contact at
the right moment — it acts when asked, and rides free when not).

⇒ and a guarantee carries a hazard this word has no name for: one that engages when it
should NOT is a **tax**, never a false ✋ — it renders no verdict to be false, so no
check reddens and the cost is invisible. see `term=engage._.choice._.md`.

## .the cost of a check that does not bite

it is not neutral. a reader takes the green of a check believed to bite as evidence,
so the box's real state goes unexamined for as long as the belief lasts.
`rule.forbid.failhide` names the general form; this term names what the repair must
demonstrate.

## .the sibling that must not be conflated

⚠️ a check can also fail the OTHER way — red against a subject that plainly works.
that is a **false ✋**, and the more corrosive of the two: a check known to lie gets
silenced and takes its neighbours' credibility along
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

so "it bites" is not "it is red". a check that is always red bites none of what it
guards; it merely trades one direction of blindness for the other. the word demands
**both** directions observed.

## .evidence

- discovery: five play names already carried the word before it earned a cluster —
  `prove.sha256-pins-bite`, `prove.apt-key-pins-bite`, `prove.keyrack-peer-probe-bites`,
  `prove.play-await-bites`, `prove.root-decline-bites`. a term reused across five
  declared operations, with no entry, is the itemization rule's own trigger
  (`rule.require.domain-term-itemization`)
- 2026-08-13: a sixth, `prove.gpg-signature-pins-bite`, landed the same round that
  captured the term — which settled it as vocabulary rather than a name
- invariant: a `prove.*-bites` play that exercises only the green direction is
  misnamed, and that is checkable by a read of its arms
