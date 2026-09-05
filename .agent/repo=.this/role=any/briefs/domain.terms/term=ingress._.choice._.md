# domain.term: ingress

term.chosen   = ingress
term.kind     = noun
term.synonyms.forbidden:
- breach          (names the OUTCOME, and only the successful one. ingress names the DIRECTION,
                   so it stays the right word for a path that was found and closed)
- intrusion       (carries a completed act. this repo grades vectors nobody walked)
- entry           (EXTANT TERM, and taken: `term=entry._.choice._.md` is a stored RECORD in a
                   rack or a registry. one word, two concepts, is the ambiguity the glossary kills)
- attack          (the whole event. ingress is one leg of it — the arrival)
- exploit         (the TOOL or the ACT. ingress is the property of the seam that admits it)
- infiltration    (a near-synonym, and the guardian role's own `infil`. forbidden HERE only to
                   keep one word per concept in THIS repo; see the dispute in `.reason`)
- escalation      (the OPPOSITE half, and the pair this word holds apart — see below)

## .what

**ingress** is remote-chosen bytes that gain influence on a **more-trusted side**, with no
already-compromised precondition.

the influence must land as one of six: CODE, a PATH/FILENAME, a TRUST ANCHOR, an ENV VAR, a
TERMINAL ESCAPE, or a WRITE DESTINATION.

## .the pair the word exists to keep apart

```
ingress     → somebody gets IN.        no precondition
escalation  → somebody ALREADY in      reaches further
```

every report names one or the other, in those words, because it is the first question a human
asks and the two carry opposite urgency.

## 🛑 .what this round SETTLED — "more-trusted" is RELATIVE, and for 21 rounds it was not

📜 measured 2026-09-02. the gradient reads:

```
open internet  <  a grove  <  the laptop
```

so it holds **two** upward arrows, and for 21 rounds only the right-hand one was ever graded.
every class a round could sweep took the laptop as its vantage, so *"ingress"* silently meant
*"reaches the laptop"* — and a result that stopped at a grove could not score above `MEDIUM`
however far it reached.

⚠️ the cost was concrete: the severity bar **capped a round below its own subject.** the first
cut of class 5 — whose whole question is how an attacker reaches a grove — carried a
`CRITICAL` rule that reserved the grade for bytes that reach the LAPTOP. its headline result
was ungradeable by its own contract.

⇒ so ingress has **two arms**, and a defect needs only one:

| arm | the more-trusted side | why it is CRITICAL |
|---|---|---|
| 1 | the **laptop** | it holds the rack |
| 2 | a **grove** | it holds `@all.camp.GITHUB_TOKEN` (`repo` + `read:org`, every org) and an aws instance role |

## ⚠️ .`ASSUME COMPROMISED` is a POSTURE, and it is not a licence to discount

the grove's tag says what the **laptop** must not trust. it does **not** say a compromised
grove is cheap, and it was read as though it did for 21 rounds. a grove is a box with an
org-wide credential on it.

⇒ so "grove only" is never a reason to downgrade on its own. name WHICH of the two assets the
defect reaches, and grade that reach.

## .refs
- `.agent/repo=.this/role=any/skills/redteam.round.sh`      # §1, §2, §7 — the contract, and the two arms
- `.agent/repo=.this/role=any/briefs/creds/howto.run-a-redteam-round.md`
- `.agent/repo=.this/role=any/briefs/creds/rule.require.github-token-at-all-camp.md`  # what arm 2 protects
- `term=entrypoint._.choice._.md`                           # the SEAM ingress arrives through
- `term=disposition._.choice._.md`                          # the other column beside severity

## .reason
see the ref-level cluster beside this choice:
- `term=ingress._.choice.reason.md` — the etymology, the `infil` dispute, and the 2026-09-02
  measurement that split the word into two arms
