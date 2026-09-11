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

## the ephemeral row cannot be PLACED, and that is its mechanism

- `EHMPATH_BEAVER_GITHUB_TOKEN` is `EPHEMERAL_VIA_GITHUB_APP`, so a `get` MINTS a
  55-minute token rather than hand back what the rack stores
- ⇒ a placement would seal a corpse that reads green forever. `git.grove.auth.keys.set`
  refuses it at step 0 and prints the duct-pane `keyrack set` instead
- 📜 the stored source has no read path and no write path
  (`vaultAdapterOsSecure.js:144` and `:193`) — an UPSTREAM gap, not a defect here
- the ask is `ehmpathy/rhachet#522`. until it lands, a human types the pem on each box,
  once per org
- ⚠️ so these two rows are the ONLY ones a fresh grove cannot converge unattended

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
