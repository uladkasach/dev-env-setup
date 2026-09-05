# howto.run-a-redteam-round

## .what

how to dispatch an ingress-security round against this repo, distilled from nine of them.

this is a **process** brief. the findings themselves live in
`.temp/handoff.security.ingress-review.md`; what follows is what makes the next round
find things rather than restate the last one.

## 🛑 .the one generative heuristic

# **THE GUARD IS RARELY ABSENT. IT IS WEAKER THAN ITS OWN CLAIM.**

nine rounds, and an outright missing check is the exception. what lands, every time, is a
guard that exists, reads as coverage, and holds less than the sentence above it promises:

| the shape | measured |
|---|---|
| a sink that guards STDOUT and not STDERR | r7 B1 |
| a reader that greps the wrong STREAM of a third-party tool, so the guard is dead code | r8 B1 |
| a verify that prints ✔ for ANY declared value, the one dangerous value included | r7 N2 |
| a pattern that can never match real input — a permanent ✔ on a destructive step | r7 N6 |
| a check blind to a command POSITION, so the house idiom is invisible to it | r8 N1 |
| a path test `!= /*` that accepts `/`, because a glob `*` matches empty | r8 N4 |
| a reader that takes the FIRST declaration where the tool resolves the LAST | r9 N1 |
| a policy declared on the outbound carrier and absent on the inbound one | r9 B2 |

⇒ so the round's question is never *"what is unguarded?"* it is:

> **for each guard, what exactly does its comment claim, and what does its code reach?**

the gap between those two is where every result has been.

## 🛑 .its SHARPEST form — A FIX THAT SHIPPED NOWHERE

round 20 found the same gap one level out, and it is the cheapest defect in this
repo to create and the hardest to see:

> **a fix that was written, reviewed, cited, and closed — and never `git add`ed —
> is indistinguishable from a fix that shipped.**

three instances, in one round:

| what was untracked | what it cost |
|---|---|
| `grove.bootstrap.sh` + 4 `src/grove.*.sh` | the published repo cannot boot |
| 9 `.play/permanent/*` + `play.run.sh` | every clamp reached exactly one box |
| `src/lazy-lock.json` | SC-F1's nvim plugin pins, reverted in effect |

⚠️ **no gate could see any of them, and the reason is one line of `find`.** every
sweep here walked the DISK, so an untracked file read exactly like a tracked one —
and each reported ✔ over all three. the moment one corpus became `git ls-files`, all
three surfaced at once.

⇒ two questions belong in every round from here:

1. **for each fix this repo believes it shipped — is the file TRACKED?**
2. **for each reader — does its corpus come from the DISK or from the INDEX?** a
   reader whose subject is "what this repo publishes" and whose enumerator is `find`
   answers a different question than the one its header asks.

### ⚠️ .the SECOND half — TRACKED is not the same as CURRENT

a `git add` run BEFORE the fix, and never re-run after it, leaves a path that is
tracked, that every presence check passes, and whose index copy is the **pre-fix**
version. a commit then ships the bug, and the repo reads as repaired.

measured on this tree, right after round 20's own blockers were closed:

```
tracked files:   840
index != disk:   127        ← 64 of them shell
```

five of those 127 were the round-20 blocker repairs themselves — `git.grove.send`,
`git.grove.operations`, and three security readers — **487 insertions that a plain
`git commit` would have left behind.** the fix was written, reviewed, cited, and
staged in a form that predated it.

⇒ so the tracked question has two halves, and a round must ask both:

| the half | what a presence check sees | what ships |
|---|---|---|
| **untracked** | the path is absent from the index | no file at all |
| **stale index** | the path is present ✔ | the version from BEFORE the fix |

`prove.declared-assets-are-tracked` clamps the bundle-asset **presence** half only —
it asks `git ls-files --error-unmatch`, which answers *is this path in the index*,
never *does the index hold what I just wrote*. the general form — a fix in any file,
in either half — still has no reader.

## 🛑 .a REPAIR is the likeliest site of the next defect

round 7 closed a defect and wrote a check to keep it closed. round 8 found that check
**half-blind** — its anchor `[;|&(]` holds no letter, so a shell's reserved-word command
position was outside its reach, and `if ! ssh …` is this repo's own idiom at six sites.

the cause is not carelessness. it is structural:

> **a check written by the author of the fix, in the same hour, against the same two lines,
> inherits that author's picture of what the subject looks like.**

a fixture proves obedience. only a subject the author did not write proves reach.

⇒ **point each round explicitly at the PRIOR round's repairs**, and name them in the
dispatch. and when a new check goes green, run it against a copy nobody just edited —
here, the INSTALLED file rather than the checkout. that one move turned a green check red.

## 🛑 .the dispatch is a COMMAND, never a prompt you retype

```sh
rhx redteam.round --classes            # what a round may sweep, and what prior ones did
rhx redteam.round --class 4            # compose round N's dispatch
rhx redteam.round --class 4 --audit    # only the DERIVED items, to check them
```

the six items below are what that command **satisfies**. read them to know what a
dispatch owes; do not hand-type one, because a hand-typed prompt drops an item silently
— the round still runs, still reports, and its report is narrower than anybody can tell.

⚠️ **three of the six are DERIVED from the tree**, and that is the point:

| item | how the skill gets it | why prose could not |
|---|---|---|
| 3 CLEAN list | read from the ledger | it grows every round |
| 4 tool caveat | **measured** — index vs disk, counted now | prose is wrong once the drift moves, and wrong forever once it lands (m.13) |
| 5 prior repairs | the uncommitted set, **ordered by mtime**, capped | a hand list names what the author REMEMBERS editing — the set their picture already covers |

⚠️ item 5's cap is a bound on the PAGE, not a claim about the tree, and the emitted
dispatch says how many it cut. its first run reported **275** files, because a rename was
in flight — a target list that long orders no reading, so the freshest repair sits at
random depth and the page still reads as thorough.

## .the dispatch contract — what a round's prompt MUST carry

a round is only as good as what it is handed. six items, and each was learned by its absence:

| # | the item | what its absence costs |
|---|---|---|
| 1 | the **trust gradient**, as one line | the agent audits for generic "bugs" and reports style |
| 2 | the **influence categories** — code, path, trust anchor, env var, terminal escape, write destination | it finds only the category it already had in mind |
| 3 | the **CLEAN list** from prior rounds | it re-walks settled ground and spends its budget there |
| 4 | the **tool caveats** for the tree's current state | a `0` from a broken reader reads as evidence of absence |
| 5 | the **prior round's repairs**, named | the freshest defect is the one nobody points at |
| 6 | the **class for THIS round** | see below |

⚠️ item 4 is not optional. a rename in flight left ~207 files in the git index and not on
disk, so `rhx grepsafe`/`globsafe` — which are index-keyed — answered `0` for files that
were plainly there. an agent handed no caveat reports that `0` as a clean sweep.

## .ROTATE THE CLASS, or the yield decays

rounds 2-8 all swept **streams** — ssh relays, the duct, skill output. by round 8 the
surface was largely clean and the findings were narrower each time.

round 9 was pointed at a different class — *a file whose CONTENT a grove authored, which a
LOCAL tool then INTERPRETS* — and found two blockers in surfaces eight rounds had not
touched.

⇒ **name one class per round and say it in the dispatch.** the classes so far:

1. the transport — what crosses the wire, and which stream carries it
2. the parse — what a value becomes when a local reader splits it
3. the interpretation — what a local TOOL does with a file a grove wrote
4. the checks themselves — a round whose subject is the prior rounds' guards

## ⚠️ .a REFUTATION is a deliverable, not a failure

say so in the dispatch, in those words. the cost of the alternative is specific:

> **a false ✋ that names a plausible fix is the most damaging output a redteam can
> produce, because the fix gets applied and IS a regression.**

it works. round 7's N4 was refuted rather than "fixed" — an edit there would have modified
correct code on a security control. round 9's N4 carried *"I am deliberately not asserting
which of these settings the trust gate overrides — that is behaviour I cannot verify from
this repo"*, which is exactly the right shape.

## .the THREE tests, run on your own finding before you report it

the first two are `gotcha.a-check-that-cries-wolf-gets-silenced`'s q7 and q8. the third was
learned in round 8 and belongs beside them:

1. **is there a site this pattern matches where the correct value is DIFFERENT?**
2. **what did the reader hand this pattern, and is that still what the file says?**
3. **does my proposed fix hold in EVERY context this code runs in?**

⇒ test 3's worked example: the round-8 report proposed a `trap … EXIT` for three `mktemp`
sites. correct for the two that are their own process. **wrong for the third**, a function
sourced into a human's interactive shell, where a trap is a second writer on THEIR signal
disposition — an EXIT trap fires when they close the terminal.

one fix, three sites, and it was a repair at two of them and a regression at the third.

## .when a set has TWO holders, diff them — the evidence is usually already here

round 8's B1: `git.grove.pull` read rsync's refusal off **stderr** and it arrives on
**stdout**, so the guard was unreachable. the proof was four files away — `git.grove.push`
reads the same notice class off stdout, and that check had been **seen red** against a
planted stale file.

⇒ **one fact with two holders is m.9, and the holder that was never measured is the wrong
one.** so a cheap, high-yield sweep: find every pair that implements one policy — two
carriers, two seats, an inbound and an outbound half — and diff the POLICY, not the code.

round 9's B2 is the same shape at the same seam: push declares `.git` never crosses, and
pull carries it back.

## .severity — report a false CLAIM even where the outcome is benign

round 8's N4: a `rm -rf` target came from the grove and was tested only for a leading `/`,
which accepts `/` itself. every consequence landed on the grove — the untrusted side — so
an attacker gained no reach they lacked.

it was still fixed, and the reason is the rule:

> **fix it because the CLAIM was false, not because the outcome was bad.** a comment that
> argues a value is safe *because it came back from a `mktemp -d`* is the answer used as its
> own evidence, and the next reader inherits the argument rather than the caveat.

grade it NITPICK, say why the blast radius is small, and fix it anyway.

## .after the round — the two records that must BOTH land

1. the **ledger** (`.temp/…`) takes the findings table, the round's own lesson, and the
   CLEAN list for the next dispatch
2. the **inventory** (`inventory.security-checks.md`) takes a row per NEW claim, with an
   honest `— (unproven)` where no reader exists

⚠️ and re-read the inventory rows the round touched. round 8's N2 found the security
inventory describing a guard by a flag it had not used since an earlier repair — the ledger
disagreed with itself about the very guard that round showed was inoperative.

## .see also

- `gotcha.a-check-that-cries-wolf-gets-silenced` — the thirteen questions; q7, q8, q11, q13
  are the ones a redteam uses most
- `gotcha.my-own-note-became-my-evidence` — the shape half these findings' comments carry
- `rule.require.seam-claims-have-an-owner` — a check must be SEEN to discriminate
- `rule.require.security-paramount` — why the cycle runs at all
- `.temp/handoff.security.ingress-review.md` — every round's findings, gitignored
