# rule.require.briefs-obey-the-prose-rules

## .what

every brief in this repo is **technical prose**, and the mechanic's `lang.prose/` cluster
governs it — `rule.require.brevity`, `rule.forbid.rambles`,
`rule.forbid.chronological-accretion`, `rule.prefer.short-sentences`,
`rule.avoid.passive-voice`, `rule.prefer.wickup-touched-prose` — voiced by `define.wick-dense`.

this rule adds **no prose rule of its own**. it declares the SCOPE, and it names the three
carve-outs this repo's briefs need.

## 🛑 .why a BINDING rule, when those rules are already in context

`.claude/settings.json:15` boots `repo=ehmpathy/role=mechanic` on every session here, so every
one of those rules is loaded, always, at say level. they still did not govern: the four largest
briefs here grew past 900 lines with the whole cluster in context.

⇒ that is a **fifth** variant of the failure `boot.yml` records four times over
(*"a rule that is not loaded is a rule that does not exist"*), and it is the harder one:

> **a rule that IS loaded, and is not BOUND to the artifact in front of you.**

an author reads `lang.prose/` as the mechanic's rules for the mechanic's artifacts — code
comments, commit bodies. a brief under `role=any` is another role's file, so those rules read
as somebody else's.

⚠️ a reviewer had the same gap from the other side: no citation existed to raise. **this rule
is that citation.**

## ⚠️ .the THREE carve-outs — and why each is load-bear

`rule.forbid.chronological-accretion` already carves out *"a changelog or an audit log whose
declared purpose IS the time-order."* this repo holds three such artifacts, and a sweep that
misses them deletes the evidence that makes its own checks trustworthy.

| carve-out | why |
|---|---|
| a `📜` that records a **MEASUREMENT** | it names what a check once got wrong, with a date. delete it and the next author re-commits the defect, since no record says it was ever considered |
| `domain.terms/term=X._.choice.reason.md` | DECLARED to hold dated disputes and etymology (`howto.domain-term-disputes`, `template.domain-term`). a `📜` there is the file at work |
| the twelve measurements of `gotcha.a-check-that-cries-wolf-gets-silenced` | they ARE this repo's evidence base, cited by number (m.4, m.6, m.7, m.9, m.10, m.12) from checks, skills, and briefs across the tree |

🛑 **the carve-out is for a MEASUREMENT, never for a CHANGELOG.** the split is what the `📜` is
ABOUT:

| the `📜` says | it is | verdict |
|---|---|---|
| *"this check read `local` and missed the pin"* | a fact about the WORLD | a record — it stays |
| *"an X play stood here until the cull took it"* | a fact about MY EDIT | a changelog — it goes |

a changelog is what git holds. so when a delete or a move makes a sentence false, **go make the
sentence true** and drop the dead pointer silently. do not leave the false claim in place with
a dated note beside it.

🛑 and the worst form is a PREAMBLE: *"read every `prove.*` name below as stale."* it leaves
every stale claim where it sits AND adds a layer the reader must diff — the accretion rule's
own `.the test` (strip every time-word; does the prose still stand?) fails it outright.

⇒ measured 2026-08-31, and it is why this section reads as it does: a cull produced seven such
📜 notes across say-level briefs and one preamble, each written in the belief that the old
*"X stood here until DATE"* line above authorized it. the human's read was *"why the fuck do
you keep [writing] chronical accretion?"* every one was removed, and the prose beneath was
rewritten to the current truth instead.

⚠️ a passage transcribed out of the file that owns it is a second COPY, and the prose rules
govern it in full.

⇒ measured 2026-08-30 on `rule.require.one-command-provision`: **1623 → 1502**, and every line
removed had another holder. four of the six cuts were the same artifact — a
`| direction | proves |` table copied out of a play into a brief.

> **a brief carries the CLAIM a check defends, never the check's own contents.** the play
> declares its directions in code that runs; a transcription of them is one claim with two
> readers, and the say-level reader is the expensive one.

## .the test, before you write a passage into a brief

> **does another file already hold this, and does that file OWN it?**

- yes → cite it. write the claim, plus one line that says where the mechanism lives
- no → it is this brief's to hold, and the prose rules govern how briefly

⚠️ and its companion, for a passage you are about to DELETE:

> **is this a RECORD of a measurement, or a second COPY of one?**

a record stays, however dated. a copy goes — and leaves a `📜` that names its new home, so the
next reader does not re-add it for want of any sign it was considered.

⚠️ and the third case, which is neither: **a sentence made FALSE by a delete or a move.** that
one is not carved out at all. rewrite it to the current truth — a `📜` about where the artifact
went is a changelog, and it leaves the false sentence in place.

## .enforcement

- a brief that violates `rule.require.brevity` or `rule.forbid.rambles` = **blocker**, at the
  severity those rules declare
- a passage transcribed out of the file that owns it = **blocker**
- a `📜` measurement record deleted as "accretion" = **blocker**; it is carved out above
- a `📜` that records where an ARTIFACT went, rather than what a MEASUREMENT found = **blocker**;
  that is a changelog, and git already holds it
- a PREAMBLE that tells a reader the claims below are stale = **blocker**; make them true
- a NEW prose rule written here that restates one of the mechanic's = **blocker**. that is the
  very defect this rule names, committed on the rule that names it

⚠️ **this is a fix-forward, never a sweep** (`rule.prefer.wickup-touched-prose`). a repo-wide
prose rewrite is the blocker that rule names, and it would meet every carve-out above at speed.

## .see also

- `define.wick-dense` — the terse persona the cluster voices
- `rule.forbid.chronological-accretion` — the carve-outs above extend its own
- `rule.prefer.wickup-touched-prose` — fix forward, on contact, in scope
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9 (one claim, two readers) and m.10 (a
  correction that reproduces the defect it records)
