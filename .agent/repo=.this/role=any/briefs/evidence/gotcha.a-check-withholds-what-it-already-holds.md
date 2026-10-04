# gotcha: a check withholds evidence it already holds

## .what

a check reads its subject, forms a verdict, and then **reports less than it read**. the
verdict is correct; the evidence behind it is on disk, in a variable, one line away — and the
reader is sent to fetch it, or never told it exists.

two faces, measured in one edit on 2026-09-28. both are the same defect at different scales.

## 🔴 .face 1 — a gate halts at the FIRST subject, so the rest are never judged

a rung that surveys N subjects and halts on the first that fails reports **one** subject. the
halt is honest. the coverage is not:

| the claim on subject 1 | what the reader loses |
|---|---|
| the driver can clear it | one climb. subject 2 is judged next time |
| 🔴 only a HUMAN can clear it | **subject 2 forever** — subject 1 fails every climb |

⇒ the cost is not paid at the moment of the halt. it is paid on every climb thereafter, and
it grows with how long the un-clearable claim stands.

### the measurement

`git.grove.ready.verify` rung 4 on `grove-ahbode-v20260811`, 2026-09-28. ground raised
exactly 2 claims — both `EHMPATH_BEAVER_GITHUB_TOKEN` rows, whose repair is a human's paste on
a laptop, because an `EPHEMERAL_VIA_GITHUB_APP` mech **mints** from a blob it never returns, so
no rack read and no forward hop can place it.

so ground could never pass, so the camper's verdict could never print. its state was knowable
only by a hand-read of a log outside the repo.

after the survey-then-halt repair, one climb:

```
      │  ├─ grove-ahbode-v20260811.ground — ✔ 192 · ✋ 2
      │  │  ├─ ✋ ahbode.prep.EHMPATH_BEAVER_GITHUB_TOKEN — the rack hands over an EMPTY value
      │  │  └─ ✋ ehmpathy.prep.EHMPATH_BEAVER_GITHUB_TOKEN — the rack hands over an EMPTY value
      │  ├─ grove-ahbode-v20260811 — ✔ 192 · ✋ 2
      │  │  ├─ ✋ ahbode.prep.EHMPATH_BEAVER_GITHUB_TOKEN — the rack hands over an EMPTY value
      │  │  └─ ✋ ehmpathy.prep.EHMPATH_BEAVER_GITHUB_TOKEN — the rack hands over an EMPTY value
```

⇒ the camper was converged to the **identical** point, and that fact had been invisible.

⚠️ **a survey is not a weaker gate.** the halt still fires, still exits 3, still names one
rung. what changes is that it names every subject at once — and it costs one remote read fewer
per climb than halt-then-resume does.

## ⚠️ .face 2 — a fix-text names a command the reader is REFUSED

the same rung's halt said:

```
  which bundles claimed —
  grep -B2 '✋' <log>
```

`grep` is not on a driver's permitted command set here, so **the one line that answers
*which* is the one line the driver cannot run.**

⇒ a fix-text that cannot be run names no fix (`rule.require.errors-name-the-fix`). and this is
the worse shape of that rule's two, because it reads as diligence: the halt appears to hand
over the next step, so a reader does not look for a gap.

⚠️ the repair is not a permitted substitute command. **the check already read the log** — it
opened it, counted it, and formed its verdict from it. so it prints the headlines itself and
asks the reader for no second command at all. a step a tool can perform is a step a tool owes
(`philosophy.entoolment-is-the-pinnacle`).

## 🔴 .face 3 — a check DISCARDS the evidence, then GUESSES in its place

faces 1 and 2 withhold evidence the check still holds. face 3 is worse: the check **throws the
evidence away at the moment it arrives**, and then prints a plausible sentence where the fact
would have gone.

the shape is one redirection:

```sh
# 👎 the status is on stderr. this drops it, and then the next line invents one
value="$(rhx keyrack get --owner ehmpath --env camp --key AWS_PROFILE --value 2>/dev/null)"
…
say "the rack handed over no camp AWS_PROFILE — likely locked 🔒"
```

⚠️ **`likely` is the tell, and it reads as honesty.** the author hedged, so a reader trusts the
hedge and acts on the guess anyway — no other line on the page is actionable.

### the measurement — 2026-09-29

`git.grove.provision.boot.sh` step 0 carried exactly that pair. and the guess is not a coin flip:

| the state | what it wants |
|---|---|
| `locked 🔒` | `keyrack unlock` |
| `absent 🫧` | `keyrack set` — which has **no entry-only mode**, so it OVERWRITES whatever is live |

⇒ 🔴 **the two repairs are opposite, and one of them destroys a credential.** both states exit 2
with empty stdout and differ only in the stream the `2>/dev/null` discarded
(`rule.require.github-token-at-all-camp`, its five-cause table · `term=swallow`).

and the same block carried a second face-3 instance beside it: the read passed **no `--org`**, so
it answered about whatever account this checkout's manifest names. for a foreign-org grove that is
a real profile from the wrong account — a read that succeeds and answers a different question
(`term=keyrack.gitroot`).

🟡 **neither reddened one row.** the first prints a hedge, the second returns a plausible value. so
face 3 is a **false ✔ generator**, where faces 1 and 2 merely withhold — which is why it belongs in
this brief rather than beside a halt.

### the repair is a HOLDER, never a wider guess

the fix is not a longer hypothesis list and not a `2>&1` capture parsed inline. it is to route the
read through the one operation that already knows the states apart:

```sh
_grant_profile="$(_rack_profile camp "$BOOT_ORG")" || _grant_profile=""
…
_rack_profile_fix camp "$BOOT_ORG"     # the repair each state wants, named by the holder
```

⇒ seven skills in this repo already read the rack that way, and its red direction was measured
the same day (rung 2 of the ready ladder surfaced `aether.camp.AWS_PROFILE status: locked 🔒`).
**so the repair reuses proven pavement rather than adding an eighth reader over one set** — which
is m.9's trap, and face 3's obvious fix walks straight into it.

## 🟡 .and the count and the list must have ONE reader

the repair introduces a second reader over one set — a counter and a lister — which is
`gotcha.a-check-that-cries-wolf-gets-silenced` m.9 exactly: free to drift on the very input the
count exists to describe.

⇒ so `_count_claims` now counts `_say_claims`'s **output**. a claim the list omits is a claim
the tally cannot count, and the two disagree by construction never. the discriminator has one
holder.

## .the test

three questions, before you trust a check's output:

> **1. how many subjects did this check read, and how many did it report?**
>
> ⇒ fewer reported than read → it withheld a verdict. ask whether the withheld one can ever
> print: if the halted subject's claim is not the driver's to clear, the answer is no.

> **2. does any line of this output send the reader to fetch evidence the check already read?**
>
> ⇒ yes → print it instead. and check that the fetch command is one the reader is *permitted*
> to run — a refused command looks identical to a helpful one.

> **3. does any line HEDGE about a state the subject already reported?**
>
> ⇒ `likely`, `probably`, `usually means`, `suspect` — each marks a place where a fact was
> available and a guess was printed. grep the call above it for a `2>/dev/null`: that is where
> the fact went. ⚠️ and ask what the WRONG branch of the guess costs — where the two states
> want opposite repairs, a hedge is a live hazard, never a soft answer.

## .see also

- `gotcha.a-check-that-cries-wolf-gets-silenced` — the false-✋/✔ family; this is its third
  axis, a verdict that is neither wrong nor printed. m.9 is the one-set-two-readers trap the
  repair had to avoid
- `rule.require.errors-name-the-fix` (ergonomist) — the rule face 2 breaks
- `rule.forbid.failhide` — the near neighbour: there the verdict is wrong, here it is absent
- `gotcha.the-duct-returns-the-send-not-the-answer` — why the repair prints from a log it read
  rather than greps another component's output format
- `git.grove.ready.verify.sh` — rung 4 carries both repairs inline, with their measurements
- `git.grove.operations.sh` — `_say_claims` / `_count_claims`, the one-holder discriminator
