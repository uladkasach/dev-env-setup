# howto.prove-bundles-plan-apply-apply

## .what

how to run the three proofs `rule.require.prove-each-bundle-plan-apply-apply` demands — `plan`,
`apply`, `apply`, per bundle, on a grove, output read — and how to read each verdict.

## 🛑 .no tracked play paves this today

`prove.bundles.plan-apply-apply` ran the three per bundle and diffed the two applies. it lived
under the gitignored `.play/temporary/`, so no checkout carries it: `--play` with that name
finds no file, on any box. the three runs below are the paved path until a tracked play under
`.play/permanent/` replaces it (`.what a tracked play owes`, below).

## .the loop

always in this order:

```sh
# 1. wake it, if the tunnel is down (rule.require.wake-the-grove-freely)
rhx git.grove.wake grove-1

# 2. land THIS worktree on the grove — the sends run what you pushed, not main
#    ⚠️ `--from .`, never `--from src`: `5.1.node` reads the package.json BESIDE
#       src/, so a .wip that holds only src/ raises a 5-claim cascade off one
#       absent manifest (howto.add-a-new-grove, `.the push USED to be partial`)
rhx git.grove.push grove-1 --from . --into git/more/dev-env-setup.wip --mode apply

# 3. run the three, through the duct — one step per send, and read each
rhx git.grove.send grove-1 --what 'rhx grove.provision --what <slug> --mode plan'
rhx git.grove.read grove-1 --lines 40
rhx git.grove.send grove-1 --what 'rhx grove.provision --what <slug> --mode apply'
rhx git.grove.read grove-1 --lines 40
rhx git.grove.send grove-1 --what 'rhx grove.provision --what <slug> --mode apply'
rhx git.grove.read grove-1 --lines 40
```

step 3 is one step per `--what` — `git.grove.send` refuses a chained one — and **never a raw
ssh** (`rule.require.reach-a-grove-through-its-duct` — `Bash(ssh:*)` is denied in
`.claude/settings.json` for exactly this reason).

step 2 is not optional. the sends run the checkout that is ON the grove. skip the push and you
will confidently prove the previous revision.

## .how to read the verdict

each bundle owes four claims, and each run's output is where you read them:

| claim breaks | what it means | is it a real defect? |
|---|---|---|
| plan mutated | an upsert line in the plan run lacks `— would run (plan)` | **always** — plan is the run a human makes first *because* it is safe |
| not idempotent | the second apply's output differs from the first in any line but a timestamp or a duration | **always** — the difference is the answer |
| prompt opened | a question was asked on a headless box | **always** — on a duct the question eats the next command sent |
| apply non-zero, both runs | both applies exited non-zero | **a gap or a defect — read each ✋** |

### the one verdict that needs your judgment

an apply that exits non-zero on both runs is NOT auto-failed. the rule's apply conditions
(`rule.require.prove-each-bundle-plan-apply-apply`, `.how`, items 2 and 3) pass it when every ✋
is a **gap** — what only a human or a credential can supply — and fail it on any **defect**.
read the output and decide which you have:

- **a genuine gap the box cannot close by itself** → the bundle is fine. `2.3.ssh` exits 1 on a
  grove because it holds no ssh key and correctly REFUSES to generate an unprotected one;
  `5.4.gh` exits 1 because it holds no `GH_TOKEN`. both name the deliberate fix
  (`plan.grove-credentials.md`). that is the design succeeding, not failing.
- **a defect** → the bundle claims to do work and the work does not land. read it as a bug.

the tell: does the ✋ name something only a **human or a credential** can supply? then it is a
gap. does it name something the **bundle itself** was supposed to do? then it is a defect.

## .what a tracked play owes, when one is written

the scratch play kept three properties the by-hand loop lacks. a replacement under
`.play/permanent/` owes all three:

- **the runs kept** — plan, apply, reapply, and their diff, per bundle, on the grove
- **the diff mechanized** — the two applies diffed, with a named allow-list of lines permitted
  to differ, so idempotency is a computed verdict rather than an eyeball
- **the set declared** — the bundles under proof as a list in the tracked play, never a walk of
  the tree. a walk proves whatever sits on disk, so the set would change silently as bundles are
  added, and "what did we claim to prove?" would stop being answerable from git

## .the caveat that limits every proof

**a converged box cannot prove a first apply.** if the grove already holds what a bundle
declares, that bundle's first apply proves dispatch and idempotency — but it does NOT prove the
work succeeds on a box that lacks it, because no part of it was lacking.

`2.1.toolkit` is the honest example: it passed all three runs, but every package was already
installed, so the run proved convergence rather than installation. `2.3.ssh` is the contrasting
case — `ssh` was genuinely absent, so its first apply really did install something.

when a from-scratch proof matters, use a fresh grove
(`howto.bootstrap-a-grove-from-scratch.md`). a proof on a converged box is real, but it is
narrower than it looks, and it should be reported as what it is.

## .the false positive worth knowing about

🛑 **never detect a mutated plan by a word search** — by eye, or in the tracked play that
replaces the scratch one. a grep for
`declared|installed|set |removed` fires on `2.2.git`, whose plan run writes not one byte — what it matches is the
**verify's** success report:

```
• git identity set (seaturtle[bot] <…>) ✔      ← matched "set "
• all 10 git aliases declared ✔                ← matched "declared"
```

past-tense state words are exactly how a verify describes a converged box, so a word search
cannot tell a verify's report from an upsert's announcement.

⇒ ask the **runtime's contract** instead: under `--mode plan`, `bundle.upgrade` prints
`— would run (plan)` for a `*.upsert` and does not call it. so an upsert line *without* that
suffix is an upsert that ran. that is a fact, not a vocabulary guess.

⚠️ **a checker that cries wolf on the healthy case is the same defect as a verify that fails
on a converged box.** both teach a reader to skip the line, so the one time it matters, nobody
looks.

## .see also

- `rule.require.prove-each-bundle-plan-apply-apply` — the rule these runs satisfy, and why a grove is the only valid target
- `rule.require.reach-a-grove-through-its-duct` — why the duct, never raw ssh
- `rule.require.idempotent-install-procedures` — the property the second apply proves
- `howto.provision-a-grove.md` — the wider grove loop this sits inside
