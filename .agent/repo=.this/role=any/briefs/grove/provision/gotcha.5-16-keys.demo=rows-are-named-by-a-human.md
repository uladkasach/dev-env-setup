# demo: 5.16.keys — every measurement behind its required-rows table

## .what

`5.16.keys` owns no artifact. it owns the CLAIM that a box can READ the keys a suite
needs. each row below is a measurement that shaped one clause of its header.

## a row says the box must READ it — never HOW it got there

a grove has two sources, and a row in `_required` is silent about which serves it:

- `aws.params` — central, and PER ACCOUNT. a NAMED-org param is addressed through THAT
  ORG's `AWS_PROFILE`, and on a grove ehmpathy's is `ambient` — the CAMP badge. so a
  value the laptop wrote into the ehmpathy account is read from camp's, and answers EMPTY
- `os.secure` — a REPLICA on the box, sealed to that box's own recipients. no aws grant
  reaches it, and `git.grove.auth.keys.set` PLACES one from a box that already holds it
- ⇒ so a row blocked on `uladkasach/dev-env-setup#123` is NOT blocked on a human: the
  placement seals a replica and the read goes green. the cost is that a rotation must be
  re-placed per box, which is what that skill's `--refresh` is for

## the account line, and why it sits in this bundle's verify at all

- 📜 measured 2026-09-06 on grove-ahbode-v20260901:

  ```
  ehmpathy: profile 'ambient'             -> = this box's ambient account
  ahbode:   profile 'ahbode.test.ehmpath' -> != this box's ambient account
  ✋ ehmpathy.test.FIREWORKS_API_KEY — EMPTY
  ✔ ehmpathy.prep.FIREWORKS_API_KEY — held
  ```

- an EMPTY answer is the only signal the rack gives, and the account it authenticated
  into is the one cause a human cannot guess from it
- ⇒ the verify prints `= ambient` / `!= ambient`, never an account id
  (`rule.forbid.dox-in-public-repo`)

## the ORG axis — settled by the human, 2026-09-07

> *"the roles will still need the orgs version of ahbode.prep.FIREWORKS_API_KEY"*

- a role composes its slug under the org of the TREE IT RUNS IN, never the org its own
  manifest pins. so `ehmpathy/role=mechanic` declares FIREWORKS, and inside
  `ahbode/svc-chat` that resolves to `ahbode.prep.FIREWORKS_API_KEY`
- ⇒ **a vendor key is per-ORG, not per-vendor.** one fireworks account may back every
  row, and each org still needs its own ENTRY — the org is an axis of the address
  (`term=slug`) and, under `aws.params`, of the ACCOUNT the read authenticates into

## 🛑 a DERIVATION FROM THE MANIFESTS WAS WRONG, 2026-09-07

the record stays, because the argument was plausible and will re-occur. the header read:

> *"FIREWORKS is the ONLY vendor key any enrolled role declares. bhrain's ROOT manifest
> adds OPENAI/ANTHROPIC/TAVILY/XAI at env.test, and those are read only by work INSIDE
> the bhrain repo — a grove that clones svc-chat never asks"*

- the human asked for all four to be placed
- ⇒ **a grove is not only a box that runs svc-chat's suite; it is a box that does BHRAIN
  work too** — a review, a route guard, a reviewer brain. those read the bhrain root
  manifest's keys
- ⇒ the defect was to derive the CONSUMER SET from one workload I had watched, then state
  it as a property of the box. a manifest says what a role DECLARES; it says none of
  which trees a grove will be asked to work in

what the manifests actually declare, which is the CHECK and never the source:

```
bhrain/reviewer    env.prep  FIREWORKS_API_KEY
ehmpathy/mechanic  env.prep  FIREWORKS_API_KEY   env.test  FIREWORKS_API_KEY
bhrain ROOT        env.test  OPENAI · ANTHROPIC · TAVILY · XAI · FIREWORKS
```

## the ORG SCOPE — settled by the human, 2026-09-07: **ahbode and ehmpathy only**

- this box's rack holds five owners; three carry no row on purpose
- ⇒ `nheuron`, `whodis`, and `whodisio` are ABSENT BY DECISION, not by oversight. a
  reader who "completes the set" from the rack would widen a scope a human narrowed

## the ephemeral row cannot be PLACED — and the reason that stood was WRONG

`EHMPATH_BEAVER_GITHUB_TOKEN` is `EPHEMERAL_VIA_GITHUB_APP`, and it cannot ride
`git.grove.auth.keys.set`. the refusal is right; the reason recorded until 2026-09-28 was
not, in a way that mattered:

> 👎 *"EPHEMERAL_VIA_GITHUB_APP MINTS its value, so there is no stored value to copy"*

- the mech stores a **PERMANENT json blob** — `{appId, installationId, privateKey}` — and
  `mechAdapterGithubApp.validate` says so outright: a `source` is that blob, a `cached` is
  the `ghs_` token. the blob does not expire; a github app private key has no clock on it
- 👍 what is true: **`keyrack get` DELIVERS the minted token and never hands back the
  source.** so a get→set pipe — which is exactly what the placer does — copies the
  55-minute token rather than the blob, and seals a corpse that reads green forever
  (`ehmpathy/rhachet#522`)
- ⇒ **same refusal, different cause, and only the true cause names a fix.** *"no value
  exists"* is a dead end; *"get returns the wrong one of two stored facts"* points straight
  at the vault

### 🛑 so the remedy is a VAULT, never a terminal on the box

`rule.require.one-command-provision`: *"any prompt, confirm, or tty read on the provision
path = blocker"*. so *"set it at a terminal"* is not a workaround for a grove — it is the
forbidden act, and a fix-text that names it sends a human to break an invariant
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4: a true verdict whose REPAIR is wrong).

- `aws.params` holds this mech — `setKeyrackAwsParamGithubApp` persists the blob into SSM
  and roundtrip-verifies it under the org's own profile
- that vault is CENTRAL, so it is written ONCE, on a human's own laptop, and every grove
  thereafter reads the blob and mints its own token with **no prompt on any box, ever** —
  which is what `@all.camp.GITHUB_TOKEN` already does
- ⚠️ the one-time set still prompts for a pem path, and that is FINE: a laptop at a human's
  keyboard is not the provision path. what the invariant forbids is a tty in the loop that
  raises a box
- ⚠️ until that one write lands, these two rows are the only ones a fresh grove cannot
  converge unattended

## why EMPTY collapses FIVE states, and why the count is not four

- 📜 the fifth arrived 2026-09-07 with this bundle's first `EPHEMERAL_VIA_GITHUB_APP` row
- a fix-text that named four would send a human to `keyrack list` and an unlock, and
  neither touches that cause
- ⇒ **a list of causes is a claim about a SET, and this set grew**
  (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11)

## .see also

- `5.16.keys/_.sh` — the header these measurements back
- `gotcha.5-12-rack.demo=entry-vs-value.md` — the ENTRY-vs-VALUE split this leans on
- `term=entry` — the cause split behind an EMPTY answer
- `rule.require.github-token-at-all-camp` — the four-state block this extends to five
