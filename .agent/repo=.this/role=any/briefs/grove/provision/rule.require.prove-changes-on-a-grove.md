# rule.require.prove-changes-on-a-grove

## .what

a change to this repo is **unproven** until it has RUN on a grove. not parsed — run.

```sh
rhx git.grove.wake grove-1
rhx git.grove.push grove-1 --from . --into git/more/dev-env-setup.wip --mode apply
rhx git.grove.send grove-1 --play prove.bundles.plan-apply-apply
rhx git.grove.read grove-1 --lines 40
```

per bundle: `plan`, `apply`, `apply` — the third run is the idempotency proof and is the
one most often skipped. then the tree-scale gate, which is the only run that sees two
bundles interact:

```sh
rhx git.grove.send grove-1 --play prove.tree.fixed-point
```

## .why a GROVE and never the laptop

- a laptop has years of installs on it, so an apply there cannot tell "this works" from
  "this box already had it" — the exact question a first apply exists to answer
- every headless gate tests `!= local@unix`, so on a laptop that branch **never executes**.
  a laptop run proves the path a grove will never take
- a grove is disposable. a first apply is the run most likely to be wrong

## .what does NOT count as proof

| looks like proof | proves |
|---|---|
| `bash -n` | the file PARSES. not one line of it ran |
| a name cross-check | the names agree. not that dispatch works or a body succeeds |
| `--mode plan` alone | the tree DISPATCHES. it skips every upsert by design |
| a diff against `origin/main` | the bytes match. not that the bytes work |

each of those is a check that cannot fail the way an apply can. to report one as proof is
`rule.forbid.failhide`.

## ⚠️ .a declined or skipped run is a BLOCKER, not a note to carry

work stops there. it does not continue "and verify later."

this has now happened twice, a day apart, in this repo:

- **2026-07-30** — 36 bundle files across eight bundles, `bash -n` on each, a static name
  cross-check, and **zero** executed. a plan run was requested twice and declined twice;
  the session kept building anyway.
- **2026-07-31** — a plan run was declined once, early. that one denial was generalized
  into "execute none of it", and six bundles were written, changed, and reported with only
  `bash -n` and `diff` behind them. the denial had been about the human's LAPTOP — which
  is the very objection a grove answers. the tool to proceed was in reach the whole time.

the second is the more instructive: the rule that forbids this was in the repo, and was
booted as neither `say` nor `ref`, so it was never in context. that is why THIS brief is
say-level and short — a rule that is not loaded is a rule that does not exist.

## .the tell

before you report a change as done, ask: **what did I actually run, and where?**

if the answer names no grove, the change is unproven — say so in those words, and do not
let a static check stand in for the sentence.

## .see also

- `rule.require.prove-each-bundle-plan-apply-apply` — the full rule: the four reasons a
  laptop cannot prove a bundle, how to read each verdict, and why the second apply matters
- `howto.prove-bundles-plan-apply-apply` — how to run the play and read its output
- `rule.require.reach-a-grove-through-its-duct` — `--play`, never raw ssh
- `rule.require.wake-the-grove-freely` — waking one is cheap; reach for it
- `rule.require.trust-but-verify` — the general form of the same failure
