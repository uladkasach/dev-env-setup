# rule.require.prove-changes-on-a-grove

## .what

a change to this repo is **unproven** until it has RUN on a grove. not parsed — run.

```sh
rhx git.grove.wake grove-1
rhx git.grove.push grove-1 --from . --into git/more/dev-env-setup.wip --mode apply
rhx git.grove.send grove-1 --what 'rhx grove.provision --what <slug> --mode plan'
rhx git.grove.read grove-1 --lines 40     # a send's output is its report
rhx git.grove.send grove-1 --what 'rhx grove.provision --what <slug> --mode apply'
rhx git.grove.read grove-1 --lines 40
rhx git.grove.send grove-1 --what 'rhx grove.provision --what <slug> --mode apply'
rhx git.grove.read grove-1 --lines 40
```

per bundle: `plan`, `apply`, `apply` — the third run is the idempotency proof and is the
one most often skipped. then the tree-scale check, the only run that sees two bundles
interact: the whole tree applied twice, then planned. every bundle that still claims must be
one a grove cannot clear itself (a credential):

```sh
rhx git.grove.send grove-1 --what 'rhx grove.provision --mode apply'
rhx git.grove.read grove-1 --lines 80
rhx git.grove.send grove-1 --what 'rhx grove.provision --mode apply'
rhx git.grove.read grove-1 --lines 80
rhx git.grove.send grove-1 --what 'rhx grove.provision --mode plan'
rhx git.grove.read grove-1 --lines 80
```

no tracked play paves these; one `--what` per run is the path.

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
  `bash -n` and `diff` behind them. the denial had been about the human's LAPTOP — the
  very objection a grove answers.

the rule that forbade this was booted as neither `say` nor `ref`, so it was never in
context. hence THIS brief is say-level and short: a rule not loaded does not exist.

## .the tell

before you report a change as done, ask: **what did I actually run, and where?**

no grove named → the change is unproven. say so, and let no static check stand in.

## .see also

- `rule.require.prove-each-bundle-plan-apply-apply` — the full rule: the four reasons a
  laptop cannot prove a bundle, how to read each verdict, and why the second apply matters
- `howto.prove-bundles-plan-apply-apply` — how to run the three and read each verdict
- `rule.require.reach-a-grove-through-its-duct` — `--play`, never raw ssh
- `rule.require.wake-the-grove-freely` — waking one is cheap; reach for it
- `rule.require.trust-but-verify` — the general form of the same failure
