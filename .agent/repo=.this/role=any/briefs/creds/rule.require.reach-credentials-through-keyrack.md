# rule.require.reach-credentials-through-keyrack

## .what

a credential is reached through **keyrack**, and through no other door. never through a raw
`aws` (or `gh`, or `op`) call — not to USE one, and above all **not to ASK whether one is
live**.

```sh
rhx keyrack unlock --owner ehmpath --env camp   # ✅ the only door
aws sts get-caller-identity --profile …         # ⛔ a different store, a different question
```

## ⚠️ .why a raw probe is worse than useless here

`aws sts` reads `~/.aws/sso/cache`. keyrack holds the credential in **its own vault**
(`vault: aws.config`) and performs the sso login itself when asked. those are two
different stores, so the raw read answers a question nobody asked and answers it the same
way forever:

```
aws sts get-caller-identity --profile ahbode.camp.ehmpath
  → Error loading SSO Token: Token for ahbode.camp.ehmpath does not exist
```

that line is what an ABSENT credential prints. it is also what a **perfectly live** one
prints, because the token was never destined for that cache. measured 2026-08-06: the read
above was run four times across twenty minutes and said `does not exist` every time — then
one `rhx keyrack unlock` answered `✓ authenticated as vlad · expires in: 540m` on the first
try.

⇒ **the probe could not see the thing it reported on.** it was bounded, it did not lie, and
it could fail — it simply asked a question whose answer does not decide the claim. that is
the `term=probe` hazard in its purest form, and it cost twenty minutes of a human being
told a door was locked while they held the key.

## .the tell

before you read a credential's state, ask: **who WRITES this?**

- keyrack writes it → keyrack must be the one to read it back
- if the answer is a different tool, you are about to measure a store no one fills

a corollary that catches the same class: a probe that answers identically for "absent" and
for "present but stored elsewhere" is not a probe. it is a constant.

## .and the reverse mistake

do not conclude from this that keyrack is fragile. it is not. the two apparent failures
that preceded the win were **run in the background**, where the sso browser handoff has no
session to hand to:

| how it was run | outcome |
|---|---|
| background (`run_in_background`) | ✋ `aws sso login timed out — human did not respond` |
| foreground | ✓ `authenticated as vlad` — first try, no prompt to the human |

so the fix was never a credential the human had to place. **run `keyrack unlock` in the
FOREGROUND.** a background run cannot raise the browser, and its timeout message blames
the human for a handoff that was never offered.

⚠️ and note the failhide beside it: one of those background runs exited **`0`** on that
same `✋`, the other exited `2`. a caller that samples the exit code once may conclude all
is well. read the OUTPUT (`rule.forbid.failhide`).

## .how

```sh
rhx keyrack unlock --owner ehmpath --env camp    # foreground, always
rhx keyrack list   --owner ehmpath               # what is on the rack, and in which vault
rhx keyrack get    --owner ehmpath --key … --unlock --value
```

`--owner ehmpath` is required on every one of them; without it keyrack reaches for the
human's own yubikey-backed manifest.

## .enforcement

- a raw `aws` / `gh` / `op` call used to READ or ASSERT credential state = **blocker**
  (it measures a store keyrack does not fill, so it is a false answer, not a weak one)
- a raw `aws` call used to obtain a credential keyrack declares = **blocker**
- `keyrack unlock` run in the background, then reported as "the human did not respond" =
  **blocker** — the handoff was never offered
- an exit code taken as a keyrack verdict, with the output unread = **blocker**

## .see also

- `rule.require.github-token-at-all-camp` — the slug every github consumer reads
- `rule.require.wrap-cli-in-skills` — why the skill, not the underlying binary
- `rule.forbid.failhide` — a failure that exits 0 is the worst kind
- `rule.require.trust-but-verify` — verify with the tool that OWNS the fact
- `domain.terms/term=probe._.choice._.md` — the hazard class this belongs to
- `domain.terms/term=rack._.choice._.md` — what the rack is
