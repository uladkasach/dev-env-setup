# gotcha: a comment states what the author INTENDED to prevent, never what the code reaches

## .what

a source comment that declares a prohibition — *"never X, never Y"* — is a statement of
**intent**. the code beneath it prevents whatever its lines actually touch, which is
routinely a **subset**.

read the comment and you have the author's goal. read the line and you have the guarantee.
they are different claims, and only the second one holds.

## 📜 .measured 2026-09-23 — it cost two wrong answers to one human question

the question: *"what auth do i need to set this key?"* the source, read at the identity
resolver:

```js
// asKeyrackAwsParamIdentity.js:13
// .note = @all → grove-wide → the grove's own ambient identity (IMDS only, never a
//         profile, never ambient SSO)
if (input.org === '@all') return { source: 'imds' };
```

⇒ i reported **"there is no laptop auth that works — not SSO, not a profile, not root"**,
and told the human to stop. the comment says *never*, twice, and the branch is one line.

the human pushed back: *"i should be able to set it with ambient auth from use.aether.camp
or something."* the applier settles it:

```js
// withKeyrackAwsParamEnvOverlay.js:23-24
if (input.awsProfile === undefined) delete process.env.AWS_PROFILE;
```

**that is the entire enforcement.** it deletes ONE variable. it never touches
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, or `AWS_SESSION_TOKEN` — and env-var
credentials sit AHEAD of IMDS in the sdk's default chain.

so the hardcut blocks a **profile** hijack, exactly as written, and does not block exported
credentials at all. the recipe the human guessed works:

```sh
eval $(aws configure export-credentials --profile aether.camp --format env)
rhx keyrack set --owner ehmpath --key GITHUB_TOKEN --org @all --env camp --vault aws.params
```

⚠️ **the first wrong answer had already been reported with a source citation beside it.**
that is what makes this class expensive: a claim backed by a quoted comment reads as
*verified*, so neither the author nor the reader re-opens it. the human's instinct was the
only thing that did.

## .why the two drift, always

a comment is written **once**, at the moment of intent. the line is written to satisfy a
test, and it has a scope its author never enumerated:

| the comment says | the line does | the gap |
|---|---|---|
| "never ambient SSO" | `delete process.env.AWS_PROFILE` | SSO **exported as env creds** passes |
| "never a profile" | `delete process.env.AWS_PROFILE` | ✔ genuinely covered |
| "the grove's own identity" | clears the var, then lets the default chain run | the chain's OTHER sources are untouched |

no line here is wrong. the comment is a **goal**, and the code reaches part of it — which
is the ordinary condition of code, not a defect to file.

## .the test

before you report that something is impossible, on the strength of a comment:

> **which LINE enforces this, and what exactly does that line touch?**

- a line that deletes one variable prevents one variable
- a line that throws prevents the whole branch
- a comment with no line under it prevents **not one thing**

⇒ and the sharper form, for a prohibition:

> **name the mechanism that would have to fail for this prohibition to leak.**

if you cannot name it, you have read the intent and not the reach.

## ⚠️ .the tell that you are about to make this mistake

you are about to tell a human **"you cannot"** — and your evidence is prose.

a *"cannot"* is the most expensive verdict to get wrong, because it ends the human's line of
inquiry. it earns the read of the enforcing line, every time. a *"can"* is self-correcting:
the human tries it and the world answers.

## .the near neighbours, and what makes this one distinct

- `rule.require.trust-but-verify` — verify an inherited claim. this is its sharpest form:
  the claim was inherited from **the code's own comment**, which feels like the source and is
  a narration of it
- `gotcha.my-own-note-became-my-evidence` — a claim i wrote becomes my evidence. here the
  note is somebody ELSE's, and carries more authority for it
- `rule.forbid.failhide` — a check that cannot speak must not print a clean line. a comment
  is a check that never ran

## .enforcement

- an impossibility reported to a human, with a comment as its evidence and no read of the
  enforcing line = **blocker**
- a prohibition cited from a `.note` or `.why` block where no line implements it = **blocker**
- a "cannot" that names no mechanism = **nitpick**; name the line, or say "i have not read
  the reach"

## .see also

- `rule.require.trust-but-verify` — the general rule; this names a source that feels exempt
- `gotcha.my-own-note-became-my-evidence` — the self-authored variant
- `howdoes.a-box-reach-an-aws-account` — carries the `@all` write path this measured
- `term=probe._.choice._.md` — a read whose answer does not decide the claim it appears to
