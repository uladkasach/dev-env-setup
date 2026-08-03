# howto: pass route self-review guards without a fight

## .what

self-review guards on a route stone (`rhx route.stone.set --as promised --that <slug>`) reject the
first few attempts by design. two mechanics drive the rejections, and neither is documented in the
driver briefs. both bit repeatedly on `.behavior/v2026_08_02.fix-claude-suggestion`.

## .why

both mechanics key off a **hash of the stone's artifact**. so every edit you make to the artifact —
including edits the review itself demands — resets the guard's state. the natural loop
(*review → fix the artifact → promise*) is the exact loop that keeps the guard unsatisfied.

knowing this converts a confusing wall into a two-line rule.

## .mechanic 1 — the 30-second timer, reset by every artifact edit

source: `rhachet-roles-bhrain/dist/domain.operations/route/guard/review/self/getSelfReviewChallengeDecision.js`

| decision | header you see | why |
|----------|----------------|-----|
| `challenge:first` | `🗿 patience, friend` + `the pond barely rippled` | first promise attempt for this artifact hash — always challenged, and the 30s timer starts **now** |
| `challenge:rushed` | `🍂 what is the rush?` (above the same block) | a re-attempt inside the 30s window |
| `challenge:absent` | `what have you seen` | the review file is not at the path the guard named |
| `allowed` | `passage = progressed` | ≥30s since this hash's trigger |

two escapes exist: ~30s elapsed, or **3 attempts on the same hash** (`plowthrough`).

> ⚠️ do not lean on plowthrough. it exists so a stuck driver is not trapped, not so you can hammer
> the command three times. if you reach it without a real second pass, you have coasted.

## .mechanic 2 — the `rN` level bumps when the artifact changes

the review file path carries a level:

```
review/self/for.<stone>._.r2.<slug>.md
                          └ level
```

**the guard assigns the level; you never compute it.** `rN` tracks artifact revisions, so it bumps
whenever you edit the artifact — including mid-review. it can repeat or jump.

if you wrote `r1` and the guard now says `r3`, it will not find your file. move it:

```sh
rhx mvsafe --from '<route>/review/self/for.1.vision._.r1.<slug>.md' \
           --into '<route>/review/self/for.1.vision._.r3.<slug>.md'
```

## .the rule that avoids both

**settle the artifact first, then write the review, then promise.**

1. read the artifact, do the real review
2. make **all** artifact fixes — this is the last time you touch it this round
3. write the review file (this does **not** reset the timer — only artifact edits do)
4. promise. copy the `articulate into` path **verbatim** from the guard's output

step 3 usually takes longer than 30s, so the timer expires while you do useful work. that is the
design working, not a delay to route around.

## .the gotcha inside the gotcha

the guard prints the correct path in **both** the challenge block and the `lets reflect` block —
and it may differ from where you just wrote. **re-read it on every rejection.** a stale level is the
single most common cause of a repeat rejection after a genuine review.

## .a note on the route being sealed

you cannot read `<stone>.guard` directly — a `route.mutate.guard` hook blocks it and points you at
`rhx route.drive`. so the guard's stdout is your only view of what it wants. read it closely rather
than guess at the file.

## .see also

- `rule.always.drive-autonomously` — do not ask permission to continue; drive
- `howto.run-self-reviews` (bhrain driver) — names the level pitfall but not the timer
- `rule.forbid.gerunds` — the write hooks on this repo reject gerunds in review prose too; expect
  `noting`, `setting`, `reading`, `something` to bounce
