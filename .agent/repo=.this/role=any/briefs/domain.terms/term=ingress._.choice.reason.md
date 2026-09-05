# domain.term.choice.reason: ingress

## .etymology

latin *ingressus*, "an entrance" — the noun of arrival, and the antonym of *egress*. it names
a DIRECTION, never an outcome, which is exactly the property this repo needs: a seam that
admits remote bytes is an ingress seam whether or not anybody walked it. `breach` and
`intrusion` both smuggle in a completed act, so neither can name a vector that was found and
closed — and almost every vector this repo grades is one nobody walked.

it also pairs cleanly with `escalation`, and that pair is load-bear: a human's first question
of any result is *"did somebody get in, or did somebody already in reach further?"*

## .disputes

### dispute: infiltration / infil — raised 2026-09-02 — status: RESOLVED (keep `ingress` here)
- raised.by  = the guardian-role lift review
- claim      = `ehmpathy/rhachet-roles-ghlitch`'s guardian role wards a habitat along two
               directions it calls **infil** and **exfil**. that vocabulary is published, it
               is symmetric, and this repo's `ingress` is the same concept as `infil`. one
               concept should have one word org-wide.
- counter    = the two are NOT the same concept, and the difference is the trust GRADIENT.
               guardian's `infil`/`exfil` names a direction across ONE habitat's perimeter —
               in or out. `ingress` here names an arrival on a **more-trusted side of a
               three-level order**, which is why it can carry two arms (arm 1 laptop, arm 2
               grove) and why `escalation` is its partner rather than `exfil`. to collapse
               them would lose the gradient, and the gradient is the one fact that makes a
               severity grade derivable rather than a vibe.
               ⚠️ the asymmetry is real too: `ingress` has no `egress` twin in this repo,
               because outbound is governed by `term=dox` and the boundary excludes — a
               different mechanism with a different reader.
- resolution = keep `ingress` in this repo; record `infiltration` as a forbidden synonym HERE.
               guardian keeps `infil` for its own habitat frame. the two roles describe
               different subjects at different scales, so one word each is correct.
               ⇒ if the guardian role ever adopts the gradient, revisit — the right outcome
                 then is one shared term, not two.

## .evidence

### the measurement — 2026-09-02, and a HUMAN's question found it

the word had been in use for 21 rounds with no cluster and no written definition. its whole
sense was carried by §2 of the dispatch:

> An **ingress vuln** is remote-chosen bytes gaining influence on a more-trusted side.

that sentence is correct, and it is under-specified in one place — *which* more-trusted side.
§7 then answered that, silently and narrowly:

> `CRITICAL` is reserved for a defect where remote-chosen bytes reach the LAPTOP as CODE.

so §2 defined the term relatively and §7 graded it absolutely, and the two disagreed. nobody
caught it while every round pointed at the laptop, because on that ground the two readings
coincide.

they came apart the moment class 5 was added. the human asked:

> *"does it specifically get them to search for ingress entrypoints?"*

and the answer was no — twice over. §3 told reviewers not to hunt for absent guards, and §7
made the round's own headline result ungradeable. **the term's ambiguity stayed invisible
until a class arrived whose subject sat on the other arrow.**

⇒ this is `gotcha.a-check-that-cries-wolf-gets-silenced` q6 aimed at a WORD rather than a
check: *what exactly does this claim, and is the rule I cited about THAT claim?* one word
answered two questions differently, and the wrong answer was the authoritative one.

### why the fix is two ARMS and not a widened sentence

the obvious repair is to reword §7 to "a more-trusted side" and let the reader infer. that
fails `rule.forbid.failhide`'s spirit: it leaves the grade derivable only by somebody who
already holds the gradient in mind, and a reviewer who does not would default to the laptop
again — the same silent narrow read, one layer down.

two arms, each of which names its side and the asset that makes it critical, cannot be read
narrowly.

## .see also
- `term=escalation` — ⚠️ NOT YET ITEMIZED. the partner half of the pair above; owed a cluster
- `term=entrypoint._.choice._.md` — the seam ingress arrives through
- `term=disposition._.choice._.md` — the severity/disposition split this word sits beside
