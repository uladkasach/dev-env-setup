# rule.require.a-grove-reaches-its-own-org-only

## 🛑 .the rule, in one line

# **A GROVE REACHES ITS OWN ORG. EVERY CROSS-ORG REACH IS AN OPT-IN, DECLARED ROW BY ROW.**

an `aether` grove reaches aether accounts. an `ahbode` grove reaches ahbode accounts. neither
inherits the other's reach, its keyrack rows, or its profiles — by default, and by construction.

## .the three clauses

| # | the clause | what it means |
|---|---|---|
| 1 | **own-org by default** | a grove's reach table is derived from ITS org. a row for another org is never the default |
| 2 | **cross-org is an OPT-IN** | one org may be granted reach into another — and only as an enumerated row, under that org's own opt-in, for a named account and a named role |
| 3 | 🔴 **an UNKNOWN org gets ZERO rows** | a grove whose org has no declared table reaches no account at all. it does not fall back to some other org's table |

⚠️ **clause 3 is the safety clause, and it is the one a "sensible default" deletes.** a fallback
reads as helpful and is the exact mechanism that gave an aether box ahbode's reach table.

## 🔴 .why the failure is SILENT, and why it points the WRONG WAY

a grove that inherits a foreign org's rows does not error at wiring time. it errors at USE time,
as `AccessDenied` on `sts:AssumeRole` — and that message is **identical** in two opposite cases:

| what is true | what aws prints |
|---|---|
| this box SHOULD reach here, and is outside the trust policy | `AccessDenied` on `sts:AssumeRole` |
| this box should NOT reach here at all | `AccessDenied` on `sts:AssumeRole` |

⇒ so the repair that writes itself — *"file an ask; get the role trusted"* — is **correct for row
1 and catastrophic for row 2**. it is addressed to somebody with the power to grant, it reads as
diligence, and what it buys is a permanent cross-account expansion to silence a check that was
right.

## .the two questions, and the ORDER is the whole rule

> **1. SHOULD this box reach here at all?**
> **2. and only then — is it TRUSTED to?**

| 1 | 2 | the repair |
|---|---|---|
| ✔ yes | ✋ no | an infra ask. the trust policy is the thing to change |
| ✋ no | — | 🔴 **ours.** the row stops being asked for. no grant is owed, and none may be sought |

⚠️ question 2 is the one that gets asked first, because it is the one the error message names.
question 1 is answered by the ORG, and the error message says no word about it.

## 📜 .measured 2026-09-24 — an ask was filed that would have widened a blast radius

an `aether` grove refused five `sts:AssumeRole` calls into ahbode and ehmpathy accounts. an ask
was drafted to have `aether-camp-grove-role` trusted on `ahbode-prep-for-grove`,
`ahbode-prod-for-grove`, and `ehmpathy-demo-for-grove`.

the wisher stopped it: **there is zero ahbode relationship on an aether grove.**

### .what the box was actually told to want

| holder | what it declares |
|---|---|
| `5.13.reach/_.sh` → `_envs` | `ahbode:test ahbode:prep ahbode:prod ehmpathy:test ehmpathy:prep` |
| `5.13.reach/_.sh` → `_srcorg` | `ahbode` |
| `5.12.rack/_.sh` → `_declared` | `ahbode) camp test prep prod` · `ehmpathy) test prep prod` · `*) return 1` |
| `5.12.rack/_.sh` → `_awsprofile_rows` | `ahbode:camp ehmpathy:prod` |
| `5.16.keys/_.sh` → its rows | `ahbode:prep:…` · `ehmpathy:prep:…` |
| `5.10.repos/_.sh` → its clone set | `ehmpathy ahbode whodisio` — declared TWICE, once per half |
| `git.grove.provision test` → `REPO` | `ahbode/svc-chat` |

**seven hardcoded tables, not one `aether` row, and no org-scope mechanism at all.** so an aether
grove inherits ahbode's reach table by construction, and the five refusals are aws correctly
denying a hop nobody should have asked for.

⚠️ **the last two are the widest and the worst, in that order.**

- `5.10.repos` has the widest BLAST RADIUS of the seven. a reach row buys one account; a clone
  set buys **every repo a token can see** — so an aether grove cloned ahbode's, ehmpathy's, and
  whodisio's entire private repo sets, and cloned no aether repo at all
- the gate is the worst PLACE for it. every other table wires a capability; this one decides
  **what a PASS means**. an aether box stood up ahbode's testdb, ran ahbode's suite, and printed
  a verdict about ahbode's code

⚠️ **no check caught it, and every check was right.** each verify read its declared row and
reported the truth about that row. the defect sat one level up, in WHICH ROWS WERE DECLARED —
and a reader that reads a row can never see a row that should not be there.

⇒ one defect, seven symptoms (`rule.require.solve-at-cause`, its bulk-failure clause): five
reach claims plus two `5.16.keys` claims, all one cause.

## 🛑 .a per-org table is a MAP, and never an identity

the KEY of every table above is `GROVE_ORG` — the org the **keyrack** resolves against. the VALUE
is a different namespace each time: an aws account, a github org, a repo path.

⇒ **the two namespaces are free to disagree, and they do.**

📜 measured 2026-09-24: `aether` is the keyrack org; `aether-auctions` is the github org. an arm
written as `aether) printf 'aether'` listed an org github does not have, `gh repo list` answered
with an empty set, and the bundle reported `the token can see no repos here` — **a true verdict,
about an org nobody owns.**

⚠️ that is the trap: the wrong value did not error. it produced a well-formed, honest-looking
report about a subject that does not exist. a reader would have chased the token's scope.

⇒ **read the target namespace before an arm is declared** — `gh repo list <org>`,
`aws sts get-caller-identity`, a clone. never assume the key spells the value
(`rule.require.trust-but-verify`).

## ✔ .the worked example of clause 2 — ahbode → ehmpathy demo

this is the ONE cross-org reach this repo declares, and it is the shape clause 2 describes:

- **ahbode** opted into reach from its camp account into the **ehmpathy demo** account
- it is an opt-in, per org, for a named account and a named role — never a property of groves
- **ehmpathy is a candidate only because it is generic infra.** that is why the opt-in was
  available to grant at all

🔴 **and it does not generalize.** that ahbode opted in says nothing about aether. an aether
grove has no ehmpathy row unless aether itself opts in, for its own reasons, as its own decision.

⇒ the misread to avoid: *"ehmpathy is shared, so every grove gets it."* it is shared in the sense
that it CAN be opted into, never in the sense that it IS.

## .the test

before you write a reach row, a rack row, or a keys row:

> **whose org does this row belong to, and is this grove's org that org?**

- same org → the row is the default. write it
- different org, and that org opted in → an enumerated row, under the opt-in, naming the account
  and the role
- different org, with no opt-in → 🔴 **no row.** not a fallback, not a default, not "it is
  probably fine"

and when a hop is REFUSED:

> **before you draft an ask — does this grove's org have any business in that account?**

no → the ask is not infra's to answer. the row is ours to remove.

## .enforcement

- a reach, rack, or keys row that names an org other than the grove's own, with no declared
  opt-in = **blocker**
- a table that falls back to another org's rows for an unknown org = **blocker**; an unknown org
  gets zero rows
- an infra ask filed for an `AccessDenied` where question 1 was never asked = **blocker**
- a cross-org opt-in expressed as a blanket grant, rather than as enumerated rows naming an
  account and a role = **blocker**
- an opt-in granted to one org, cited as precedent for another = **blocker**; an opt-in is that
  org's decision and does not generalize
- a grove's org read from any source other than its own declaration — inferred from a repo name,
  a checkout, or the table that happens to be there = **blocker**
- a per-org table grown an axis, with the readers that grade it left unwalked = **blocker**; they
  then read zero rows and report a clean pass
- a per-org arm whose VALUE was assumed to spell its KEY, with no read of the target namespace =
  **blocker**; the two are different namespaces, and a wrong value reports honestly about a
  subject that does not exist
- a gate, suite, or acceptance target hardcoded to one org's tree = **blocker**; it decides what
  a PASS means, so a foreign target makes the verdict about foreign code

## 🛑 .the clamp

```sh
rhx play.run --play prove.org-scoped-rows
```

it walks every org each table declares an arm for, and grades each row's TARGET against
own-org plus the opt-ins the play enumerates — so a new cross-org row reddens until a human
enrolls the pair beside its reason. its fix-text names **delete the row**, never the grant,
which is the half the 2026-09-24 measurement proves a reader will otherwise reach for.

⚠️ the org set it walks is DERIVED off the `case` arms, never typed into the play. a typed
list is a second holder of the tables' own fact and goes stale in silence
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9 and q11).

🛑 **and the axis blinded a SIBLING clamp the hour it landed.**
`prove.reach-envs-are-declared` reads the reach table, which now keys on `GROVE_ORG` — and a
play run carries none. so it read ZERO rows, asked not one of its claims, and printed a clean
✔ against a table it never opened. the repair is the same in both: walk the derived org set,
and treat an empty read as `exit 2` rather than as a pass.

🛑 **and the play committed the same defect on itself, the afternoon it was written.** two
claim sections were added — for `5.10.repos` and for the gate — and the org derivation was left
at the three tables it opened with. so `aether`, declared by only those two, was never walked:
the run printed 22 ✔ and a green verdict over rows it never opened.

⇒ **a table added to the claims is added to the derivation in the SAME edit.**

⇒ **a per-org axis silently narrows every reader that does not know of it.** when a table
grows an axis, the readers that grade it are part of the change, never a follow-up.

## .see also

- `handoff.infra.grove-account-reach` — the withdrawn ask, and the record of why it was withdrawn
- `rule.require.solve-at-cause` — one defect, seven symptoms; its bulk-failure clause
- `rule.require.trust-but-verify` — a claim's BOUNDS are part of the claim
- `gotcha.a-check-that-cries-wolf-gets-silenced` — its inverse: here every check was RIGHT, and
  the defect sat in which rows were declared
- `rule.require.narrowest-terminal-grant` — the same instinct, one scope out
