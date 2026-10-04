# rule.require.ask-human-grants-upfront

## 🛑 .the rule, in one line

# **A GRANT ONLY A HUMAN CAN MAKE IS ASKED BEFORE THE RUN, NEVER DISCOVERED INSIDE IT.**

a long unattended run may not spend forty-five minutes to arrive at a question the human
could have answered in ten seconds at the start.

## .what counts as a HUMAN-ONLY grant

a value **no box can derive**, at all, by any convergence:

| the grant | why no bundle converges it |
|---|---|
| a github pat | MINTED at github, by a person, in a browser |
| an sso approval | a human clicks it |
| a quota, a role grant, an account permission | an administrator awards it |
| a decision about scope or a name | the wisher's to make |

⚠️ **the test is not "is it absent?" — it is "could a bundle place it?"** an absent package,
an absent config, an absent unit are all machine-fixable, so each belongs in a bundle and each
is a claim (`rule.forbid.deferred-provision-defects`). a pat belongs to neither category: it is
not a defect, it is an **unanswered question**.

## .why the MOMENT is the whole cost

the grant is equally absent at minute 0 and minute 45. what differs is what the absence costs:

| asked at | the cost |
|---|---|
| **minute 0**, before anything is driven | one question, ten seconds, then the run proceeds |
| **minute 45**, as a claim in the report | the whole run is spent, the human is interrupted anyway, and the run must be driven AGAIN |

⇒ so a preflight buys **no new information**. it buys the information **earlier**, and earlier
is the entire value. a check that could have run first and did not has charged the human a full
run for an answer it already knew it would need.

## 📜 .measured 2026-09-21 — `grove-aether-v20260921`

both seats provisioned end to end. the report: **15 claims**, of which **3 were one absent
`@all.camp.GITHUB_TOKEN`**. the human was then asked for the pat, placed it in under a minute,
and the run was driven a second time.

the wisher's read: *that should have been a preflight check before we even tried to connect.*

⚠️ **the token's absence was never a defect.** every bundle behaved correctly —
`5.12.rack` refused a set it could not honestly make, and said so. the defect was that the
**question arrived last**, and no part of the path was shaped to ask it first.

## .the shape a preflight owes

a grants step runs **before the transport is touched**, and each grant answers on **three**
arms, never two:

| arm | what it means | what it does |
|---|---|---|
| ✔ | the grant is placed | proceed |
| ✋ | it is **genuinely** absent | halt, and name the command a HUMAN runs |
| 🌙 | this box **could not tell** | say so, name why, and **proceed** |

🛑 **the third arm is the discipline, and it is the one that gets dropped.** a preflight that
cannot reach the vault has learned no fact about the grant. to score that silence as an
absence is a **false ✋** — the failure that gets a check silenced
(`gotcha.a-check-that-cries-wolf-gets-silenced`). to score it as a ✔ is the other half, and
`rule.forbid.failhide` forbids it.

⇒ and the probe reads **existence, never the value**. the secret belongs to the box that will
consume it; a preflight that pulls it has widened its own blast radius for no gain.

## .the test — TWO questions, and the second is the one that gets dropped

before a run that will take minutes with no human at the keyboard:

> **1. could a BUNDLE place this?** yes → it is a claim, and the bundle is what to fix
> **2. could the HUMAN place it, at the keyboard, right now?** no → it is still a claim

| 1. bundle can | 2. human can, now | verdict |
|---|---|---|
| ✔ | — | a **claim**. fix the bundle (`rule.forbid.deferred-provision-defects`) |
| ✋ | ✔ | 🔴 a **preflight rung**. this is the only cell that earns one |
| ✋ | ✋ | a **claim**, and a filed ask beside it |

⚠️ **question 2 is what keeps the preflight honest.** question 1 alone reads as *"human-only ⇒
preflight"*, and that is false: a grant a human cannot clear at the keyboard produces a halt on
**every** invocation, on a condition no human present can answer.

⇒ and a halt like that does not sit quietly, correct and unread. it gets `--from 1`'d past within
a day, and takes the credibility of the rung beside it along with it
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

## 🛑 .the two grants this rule was then APPLIED to, and DECLINED

both surfaced on the same box, in the same report, and both are human-only. neither earned a rung,
and the reasons are the two ways question 2 answers no.

### ✋ the cross-account reach — a human, but not at a keyboard

`5.13.reach` wants this grove's camp role trusted on three `*-for-grove` roles. an administrator
awards that, so question 1 says human-only.

question 2 says no, for **two** independent reasons:

1. **the ask is a round trip to another team's roadmap**, never a ten-second act. the pat cost the
   human under a minute; a trust-policy change costs a conversation
2. 🔴 **this laptop cannot even ASK the question cheaply.** the trust policy names the GROVE's role
   as principal, so a probe from here measures the LAPTOP's reach — a different question. to read
   the policy directly needs credentials in each TARGET account, which is three sso logins, and an
   sso login can open a browser ⇒ **the preflight would become interactive**, which
   `rule.require.one-command-provision` forbids outright

⇒ so a rung here answers 🌙 on every run, forever. **a rung whose verdict never varies reports
naught** — it is decoration, and `rule.forbid.exemption-as-habit` names that shape one level out.

⇒ it is a **claim**, and the ask is filed: `handoff.infra.grove-account-reach`.

### ✋ the `EPHEMERAL_VIA_GITHUB_APP` rows — a human, but not YET

two rack rows hand over an empty value. the mint needs a human at a **tty on the box**:
`rhx duct.open <grove>`, then a `keyrack set` typed in that pane.

question 2 says no for the sharpest possible reason: 🔴 **on a first boot the box does not exist
yet.** there is nowhere to place the grant at minute 0, so *"ask upfront"* names an act with no
subject.

⇒ it is a **claim**, and a post-provision act by nature.

#### 📜 .measured 2026-09-23 — and the FIRST read of it was inherited, not measured

the cause was carried into this brief from a summary as *"an ephemeral mint"*, and the claim's own
fix-text warns that `EMPTY collapses five states`. so it was read three ways before it was read
once — `rule.require.trust-but-verify`, and `gotcha.my-own-note-became-my-evidence`.

what three rack reads actually establish:

| where | what it holds |
|---|---|
| both seats' racks | **16 entries, and the slug is absent from both orgs** ⇒ cause 1, no manifest entry |
| this laptop's rack | both rows are `EPHEMERAL_VIA_GITHUB_APP` |

⇒ **the two facts compose, and that composition is the durable half:**

> `git.grove.auth.keys.set` forwards a value over one encrypted hop, and it forwards a **REPLICA**.
> an EPHEMERAL mech has no value at rest to forward — it MINTS one, through a github device flow
> that wants a human. so the skill declined these two correctly, and placed the other eight.

that is why the box reads EMPTY: the entry is absent **because** the mech forbids the one transport
that could have placed it unattended. ⚠️ a reader who stops at *"no entry"* reaches for
`auth.keys.set` and finds it silent; a reader who stops at *"ephemeral mech"* cannot say why the
other eight landed.

### ⇒ what the pat had that neither has

| | human-only | placeable at minute 0 | blocks the run |
|---|---|---|---|
| `@all.camp.GITHUB_TOKEN` | ✔ | ✔ | ✔ |
| the cross-account reach | ✔ | ✋ | ✋ |
| the `GITHUB_APP` rows | ✔ | ✋ | ✋ |

**all three columns, or it is a claim.** the pat is the one grant in this repo that holds them,
which is why step 0 carries exactly one rung — and that count is a measurement, not an omission.

## .enforcement

- a human-only grant surfaced as a claim at the end of an unattended run, where the human COULD
  have placed it at minute 0 = **blocker**
- a preflight step that is opt-in rather than the default = **blocker** (a human who knew to
  ask for it did not need it)
- a preflight arm that scores "could not tell" as either ✔ or ✋ = **blocker**
- a preflight that reads a secret's VALUE where its EXISTENCE answers the question = **blocker**
- a machine-fixable gap moved into the preflight rather than into a bundle = **blocker**
  (that inverts `rule.require.one-command-provision` — the run is what converges a box)
- 🔴 a preflight rung that halts on a grant the human cannot clear at the keyboard = **blocker**;
  it fires on every run, and it is the rung that gets the preflight skipped
- a preflight rung whose verdict is 🌙 on every possible invocation = **blocker**; it reports no
  fact, and its presence claims that it does
- a preflight rung that opens an sso browser prompt, or any other tty read = **blocker**
  (`rule.require.one-command-provision`'s non-interactive clause)

- a human-only grant surfaced as a claim at the end of an unattended run = **blocker**
- a preflight step that is opt-in rather than the default = **blocker** (a human who knew to
  ask for it did not need it)
- a preflight arm that scores "could not tell" as either ✔ or ✋ = **blocker**
- a preflight that reads a secret's VALUE where its EXISTENCE answers the question = **blocker**
- a machine-fixable gap moved into the preflight rather than into a bundle = **blocker**
  (that inverts `rule.require.one-command-provision` — the run is what converges a box)

## .see also

- `rule.require.one-command-provision` — the bar; a preflight protects it rather than relaxes it
- `rule.forbid.deferred-provision-defects` — the machine-fixable half: fixed now, never filed
- `gotcha.a-check-that-cries-wolf-gets-silenced` — why the 🌙 arm exists
- `rule.forbid.failhide` — why the 🌙 arm may not be a ✔
- `rule.require.errors-name-the-fix` — a halt names a runnable command, never a symptom
- `git.grove.provision.boot.sh` — step 0, where this rule is implemented
