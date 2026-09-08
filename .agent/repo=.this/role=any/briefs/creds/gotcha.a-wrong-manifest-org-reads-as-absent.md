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
