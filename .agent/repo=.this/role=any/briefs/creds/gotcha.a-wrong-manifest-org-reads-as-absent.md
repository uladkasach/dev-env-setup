# gotcha: a wrong manifest org reports `absent 🫧`, never a mismatch

## .what

`.agent/keyrack.yml`'s `org:` is what `@this` resolves to, so it decides WHICH org's slug every
`git.grove.*` skill reads. set it wrong and every grove reach fails with `absent 🫧` — a word
that means *"no credential exists"* and here means *"you asked the wrong org."*

the rack holds the credential the whole time.

## 🛑 .the asymmetry that makes it opaque

one mismatch, two verdicts — and the skills take the quiet one:

| the read | verdict on the SAME mismatch |
|---|---|
| `keyrack get --org <x>` — explicit | ✔ **fails loud**: `org 'x' does not match manifest org 'y'` |
| `@this` — implicit, what every skill uses | ✋ `absent 🫧` |

⇒ the loud path exists and is not on the route a human travels. `git.grove.wake` reads
`@this.camp.AWS_PROFILE` with **no `--org` flag**, and `keyrack unlock` accepts no `--org` at
all — so the manifest is the only lever, and it gives no signal when it is wrong.

## 📜 .measured 2026-09-06

this repo's manifest read `org: ehmpathy` after a hand-edit. every `git.grove.*` command
declined with `absent 🫧`. `rhx keyrack list --owner ehmpath` showed a healthy
`ahbode.camp.AWS_PROFILE`, whose account matched the grove registry exactly.

the correct value is `ahbode` — **the groves live in the ahbode camp account.** the whole
outage was one word in one line, and no reader named it.

⇒ tracked upstream as `ehmpathy/rhachet#502`.

## 🛑 .measured 2026-09-21 — the same verdict, and the manifest is RIGHT

the 2026-09-06 read treats a wrong `org:` as a **typo**, so its whole repair is "put the right
word back". that assumes one word can be right — i.e. that every grove lives in one org.

a grove in the **aether** camp account disproves it. `org: ahbode` is correct for every other
credential this repo reaches, and `git.grove.wake` still halts:

```
🔐 keyrack
   └─ ahbode.camp.AWS_PROFILE
      └─ status: absent 🫧
```

the rack holds `aether.camp.AWS_PROFILE` the whole time, and the explicit read refuses to
reach it:

```
✋ ConstraintError: --org 'aether' does not match manifest org 'ahbode'
   └─ hint: use an org under 'ahbode', or pass --org @all
```

⇒ so `absent 🫧` has a **fifth** cause, and it is the one no repair above touches: the slug is
filed under an org this repo may not ask for. the manifest is not wrong; it is **singular**,
and the grove fleet no longer is.

### why no lever here is safe to pull alone

| lever | why it is not the fix |
|---|---|
| flip `org:` to `aether` | this brief's own enforcement calls it a **blocker** — it silently repoints every `ahbode.*` credential |
| `keyrack set` under `ahbode.camp` | a second holder of a fact `aether.camp` already holds, and `set` OVERWRITES |
| refile the slug under `@all` | `@all` is for a credential that belongs to NO org; an account profile belongs to exactly one |

⚠️ **a grove record carries `env` and `account`, and no `org`** — so the org is not a fact the
registry can hold, and every `git.grove.*` read falls through to the manifest's single value.
that absent axis is the cause; the four repairs above are all attempts to encode a second org
in a slot built for one.

## .the test

> a camp slug reports `absent 🫧`. did I read the manifest's `org:` line before I believed it?

- no → read it. one line, and it is the likeliest cause
- yes, and it is right → then the four causes in `term=entry` apply

## 🛑 .do NOT reach for `keyrack set`

`absent 🫧` reads as *"a set will fix it"*. it will not, and it is destructive:
`set` has **no entry-only mode** and OVERWRITES a live value
(`rule.require.github-token-at-all-camp`). a blank stdin stores an empty value and still
prints `✔ set`.

⇒ **read the rack first.** `rhx keyrack list --owner ehmpath` names every entry's real org and
vault, is free to run, and is the one fact here that cannot go stale.

## .enforcement

- an `absent 🫧` diagnosed without a read of the manifest's `org:` line = **blocker**
- an `absent 🫧` on a slug the rack holds under ANOTHER org, repaired by any of the three
  levers above = **blocker**; the cause is the absent per-grove `org` axis, and it is a
  human's call, not a lever to pull mid-task
- a `keyrack set` run against an `absent 🫧` with no prior `keyrack list` = **blocker**
- a manifest `org:` hand-edited to reach one credential and left that way = **blocker**; it
  silently repoints every other credential in the repo

## .see also

- `.agent/keyrack.yml` — the `org:` line, with this measurement inline beside it
- `rule.require.github-token-at-all-camp` — the four causes `absent 🫧` collapses, and why a
  `set` is the dangerous repair
- `domain.terms/term=entry._.choice._.md` — the store-vs-value split this instantiates
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.4: a correct verdict about the wrong
  subject; `absent` is true of the slug asked for and false of the one meant
