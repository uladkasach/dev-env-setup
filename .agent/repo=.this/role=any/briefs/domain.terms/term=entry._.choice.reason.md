# domain.term.choice.reason: entry

## .etymology

`entry` was already in this repo's prose before it was a term. `grove.auth.github.roadmap.md`
uses it four times, and in every one the concept is the STORED RECORD rather than its address:

```
:169  one entry, scoped per request
:211  how the box learns the entry exists
:223  why `--scope` and not one entry per org
:225  the credential entry is one, and the request narrows it
```

`term=slug._.choice.reason.md` noticed those four lines on 2026-08-02, forbade `entry` **as a
word for the address**, and left it deliberately in place with a prediction:

> if the rack ever needs a term for "the stored record as distinct from its address", `entry`
> is the word to reach for, and it would be a NEW cluster — not a rename of this one.

that condition was met the next day. this is that cluster, and the word is the one already on
the page rather than a coinage.

## .the measurement that split it from `slug`

grove-1, 2026-08-03. the entry and the address came apart, visibly:

| what was asked | what keyrack answered |
|---|---|
| `keyrack set --org @all --env camp --key GITHUB_TOKEN` | `✔ set` |
| `keyrack list` | `@all.camp.GITHUB_TOKEN` · mech `PERMANENT_VIA_REPLICA` · vault `os.secure` |
| the vault on disk | a fresh `.age` file, mtime matching the set to the minute |
| `keyrack get --org @all …` | `status: absent 🫧` |
| `keyrack get --key @all.camp.GITHUB_TOKEN` | `BadRequestError: slug org '@all' does not match manifest org 'ahbode'` |

rows 1–3 are the ENTRY: stored, listed, on disk. rows 4–5 are the SLUG: unresolvable, because
the read path validates a slug's org against the manifest's and the write path does not.

an entry with no reachable address is the exact state that cost two real pats. it is invisible
to any vocabulary that has one word for both.

### ⚠️ the split is real; this particular measurement is not — corrected 2026-08-05

at rhachet@1.45.1 an `@all` slug **resolves**. row 5's `BadRequestError` is gone, and a real
`@all` entry read back 108 bytes on stdout against a 0-byte absent-key control. row 4's
`absent 🫧` is the weaker half still: that probe wrote a fake classic-pat-shaped value and
never confirmed it landed, so the store had likely been refused by the pat firewall or kept
empty. **the entry may never have existed** — which would make row 4 a truthful answer about
an absent entry rather than an unreachable slug.

so the table above no longer demonstrates the split it was built to demonstrate.

> ⚠️ the TERM stands, and stands more firmly than before. `entry` and `slug` were split
> because `✔ set` is a claim about the stored record and says none about the address — and
> **the correction proves that very point twice over**: a `✔ set` was again read as "the
> value is there", and the value was probably absent the whole time. an entry the writer
> never confirmed is exactly the concept this word exists to name.
>
> what failed was the *evidence*, not the distinction. keep the word; date the proof; and
> when a term file cites a bug, re-run the bug before you cite it again.

a cleaner demonstration of the split, from the same round: the grove's global `rhx` shim.
`rhx upgrade` wrote a fresh, sound shim to `$PNPM_HOME/rhx` — the record existed and was
correct — while every `rhx` a human typed resolved to a stale copy in `$PNPM_HOME/bin`. the
artifact was fine; the name did not reach it. same shape, no credential spent.

## .why this matters more than a naming preference

`✔ set` is a claim about the ENTRY. every reader took it as a claim about the SLUG.

two mechanisms in this repo — `5.4.gh` and `git.grove.auth.github.set` — printed that `✔` and
concluded the credential was placed. neither was wrong about the entry. both were wrong about
the credential, because the sentence they wrote could not tell the two apart
(`rule.forbid.failhide`: a success reported over an unverified read).

this is the same shape as the `key` / `slug` overload that `term=slug` records — a part and its
container sharing one word — one level out: a record and its address.

## .the boundary

| concept | word |
|---|---|
| the composed address, `<org>.<env>.<KEY>` | `slug` |
| the stored record that address points at | `entry` |
| one axis of the address | `key`, `env`, `org` |
| the secret the entry holds | `value` |

`entry` remains FORBIDDEN as a word for the address — that forbid is unchanged and is recorded
in `term=slug`. what changed is that `entry` now has a concept of its own, so the forbid is a
boundary rather than a ban.

## ⚠️ .why the 2026-08-25 state earned NO term of its own

the say-file records a fifth state: an entry perfect on every axis, whose value github answers
with `401`. the reflex is to coin a word for it — `stale`, `dead`, `revoked` — and each was
declined, for the same reason:

> **it is not a state of the ENTRY. it is a state of the VALUE, held by a third party.**

the rack's record is flawless throughout. so a term for it would attach a property to the wrong
noun, and the very confusion this cluster exists to prevent — a claim about one layer read as a
claim about another — would be re-created one layer out.

the vocabulary to say it already exists and needed no addition:

| to say | reach for |
|---|---|
| the bytes keyrack holds | `entry` (this term) |
| what the issuer honours this instant | `live` (`term=live`) |
| what the rack asserts | `declared` (`term=declared`) |

⇒ so the round added a **boundary** to `entry` rather than a new word next to it. the test that
settled it: *whose fact is this?* — and the answer was never keyrack's.

## ⚠️ .why ONE term serves two stores — settled 2026-09-02

the say-file's `.what` named the keyrack alone until this date, and the term was **already in use
for the grove registry**: `gotcha.a-partial-write-discards-what-it-never-read` cites this cluster
for its instance 3, where one `git grove set --at` blanked three fields of a registry entry.

so the declaration was narrower than the use. two ways to close that, and only one is right:

| move | verdict |
|---|---|
| coin a second word for the registry's records | ✋ two words, one concept — the drift `rule.forbid.domain-term-synonyms` exists to stop |
| broaden the `.what` to the concept, name the stores as instances | ✔ taken |

the concept never was keyrack's. it is *a stored record, as distinct from its address*, and both
stores exhibit it — the failure the split predicts lands in each:

| store | the failure the split names |
|---|---|
| keyrack | `✔ set` read as "the credential is placed" — twice, one real pat each |
| grove registry | `🌲 registered` printed while three fields were blanked |

⚠️ the evidence stays **asymmetric on purpose**, and the say-file says so. every measurement in
this cluster is a keyrack one, because that store is where the split cost credentials. to
re-file half of them under a neutral title would imply a registry measurement that was never
taken (`gotcha.my-own-note-became-my-evidence`).

## .disputes

none open.

`record` is the obvious alternative and was declined for one reason: `entry` is already the word
four lines of this repo's own prose use, and no reader gains anything from the swap
(`rule.require.ubiqlang` — adopt the word in use where there is no better one).
