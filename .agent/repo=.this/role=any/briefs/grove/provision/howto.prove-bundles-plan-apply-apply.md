# howto.prove-bundles-plan-apply-apply

## .what

how to run `prove.bundles.plan-apply-apply` — the play that satisfies
`rule.require.prove-each-bundle-plan-apply-apply` for a whole set of bundles at once, on a
grove, and judges each one mechanically.

the rule says: three runs per bundle (`plan`, `apply`, `apply`), on a grove, output read. this
play is how you do that without 3N hand-typed commands and without a human who compares two
long outputs by eye.

## .why a play rather than the three commands by hand

the three commands run by hand, and lose three things:

| by hand | with the play |
|---|---|
| the idempotency verdict is a human eyeball over two ~40-line outputs | the two applies are DIFFED, with a named allow-list of lines permitted to differ |
| the outputs live in one scrollback and then are gone | every run is kept on the grove under `~/.grove.proof/` |
| "which bundles did we prove?" is a memory | the set under proof is a list in a tracked file, so it is a fact in git |

it also catches what an eye slides past — see `.the false positive` below, where its flag was
wrong AND its lesson was real.

## .the loop

three commands, always in this order:

```sh
# 1. wake it, if the tunnel is down (rule.require.wake-the-grove-freely)
rhx git.grove.wake grove-1

# 2. land THIS worktree on the grove — the play runs what you pushed, not main
#    ⚠️ `--from .`, never `--from src`: `5.1.node` reads the package.json BESIDE
#       src/, so a .wip that holds only src/ raises a 5-claim cascade off one
#       absent manifest (howto.add-a-new-grove, `.the push USED to be partial`)
rhx git.grove.push grove-1 --from . --into git/more/dev-env-setup.wip --mode apply

# 3. run the proof, through the duct
rhx git.grove.send grove-1 --play prove.bundles.plan-apply-apply
rhx git.grove.read grove-1 --lines 40
```

step 3 is a `--play`, never a chained `--what`, and **never a raw ssh**
(`rule.require.reach-a-grove-through-its-duct` — `Bash(ssh:*)` is denied in
`.claude/settings.json` for exactly this reason).

step 2 is not optional. the play runs the checkout that is ON the grove. skip the push and you
will confidently prove the previous revision.

## .how to read the verdict

each bundle gets one line. a pass is unambiguous:

```
── 2.5.zsh
   ✔ plan=0 apply=0 reapply=0 · converged · no prompt
```

a failure names which of four claims broke:

| verdict | what it means | is it a real defect? |
|---|---|---|
| `plan-mutated` | an `*.upsert` ran during `--mode plan` | **always** — plan is the run a human makes first *because* it is safe |
| `not-idempotent` | the second apply differs from the first | **always** — read the `.4.drift.txt` diff |
| `prompt-opened` | a question was asked on a headless box | **always** — on a duct the question eats the next command sent |
| `apply-nonzero(1/1)` | both applies exited non-zero | **it depends — you must judge** |

### the one verdict that needs your judgment

`apply-nonzero(1/1)` is deliberately NOT auto-failed, because the rule's own pass condition
allows it:

> exit 0, **or an exit whose failures are verify claims the box genuinely does not yet
> satisfy**

so read the output and decide which you have:

- **a genuine gap the box cannot close by itself** → the bundle is fine. `2.3.ssh` exits 1 on a
  grove because it holds no ssh key and correctly REFUSES to generate an unprotected one;
  `5.4.gh` exits 1 because it holds no `GH_TOKEN`. both name the deliberate fix
  (`plan.grove-credentials.md`). that is the design succeeding, not failing.
- **a defect** → the bundle claims to do work and the work does not land. read it as a bug.

the tell: does the ✋ name something only a **human or a credential** can supply? then it is a
gap. does it name something the **bundle itself** was supposed to do? then it is a defect.

```sh
rhx git.grove.send grove-1 --what 'cat /home/camper/.grove.proof/2.3.ssh.3.reapply.txt'
rhx git.grove.read grove-1 --lines 40
```

## .the evidence it leaves

four files per bundle, on the grove, under `~/.grove.proof/`:

| file | what |
|---|---|
| `<slug>.1.plan.txt` | the plan run |
| `<slug>.2.apply.txt` | the first apply |
| `<slug>.3.reapply.txt` | the second apply — the state every future run will find |
| `<slug>.4.drift.txt` | the diff of the two applies; empty on a converged bundle |

`.4.drift.txt` is the one to read first on a `not-idempotent` verdict. it is the answer, not a
hint toward it.

## .how to add a bundle to the proof set

edit `WHAT_ALL` in the play. that edit is the point — it makes the scope of a proof a reviewed
diff rather than an argument someone typed once.

do **not** replace the list with a walk of the bundle tree. a walk proves whatever sits on
disk, so the set under proof would change silently as bundles are added, and "what did we claim
to prove?" would stop being answerable from git.

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

🛑 **never detect `plan-mutated` by a word search.** a grep for `declared|installed|set |
removed` fires on `2.2.git`, whose plan run writes not one byte — what it matches is the
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

- `rule.require.prove-each-bundle-plan-apply-apply` — the rule this play satisfies, and why a grove is the only valid target
- `rule.require.reach-a-grove-through-its-duct` — why `--play`, never raw ssh
- `rule.require.idempotent-install-procedures` — the property the second apply proves
- `howto.provision-a-grove.md` — the wider grove loop this sits inside
