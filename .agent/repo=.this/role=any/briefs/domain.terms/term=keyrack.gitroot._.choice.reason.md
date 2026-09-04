# domain.term.choice.reason: keyrack.gitroot

## .etymology

the word is the REQUIREMENT'S own word, not ours. `getGitRepoRoot.js` throws
`Not inside a Git repository`, and the only thing it wants is a `.git`. so the concept
is "a git root", and to name it anything else would describe our workaround rather than
the demand it satisfies.

that matters because the demand is an over-requirement we expect to outlive. the domain
layer states that an `@all` key "sets with NO repo manifest and never creates one", so
the operation genuinely needs no repo. the durable fix belongs upstream in rhachet
(`rule.require.solve-at-cause`). a term named for OUR scratch directory would have to be
retired with it; a term named for the requirement simply stops being needed.

## .disputes

### dispute: rackroot — raised 2026-08-10 — status: RESOLVED (keep `gitroot`)
- raised.by  = this repo, against itself
- claim      = the directory exists FOR the rack and is owned by `5.12.rack`, so
               `RACKROOT` says what it is for. it also disambiguates from "the repo's
               own git root", which a bare `GITROOT` might be mistaken for.
- counter    = the variable does not always hold the rack's scratch dir. its FIRST
               choice is `$PWD` whenever the cwd is already a repo — so on a laptop it
               is the checkout, and `RACKROOT` would name it falsely. what the variable
               actually holds is "the git root to run keyrack from", every time.

               and the disambiguation the claim wants is already carried by scope:
               `5.12.rack`'s function is `grove_provision_5_12_rack_gitroot`, so the
               `rack` prefix is on the NAMESPACE where it belongs. to repeat it inside
               the leaf is redundant in one file and wrong in the other.
- resolution = keep `gitroot`; record `rackroot` as a forbidden synonym.

📜 this dispute is against a synonym **I introduced in the same round I itemized the
term**. `aws.reach.set` grew a `RACKROOT` while `5.12.rack` already declared a
`_gitroot`, so one concept had two words across two files that now depend on each other
— the exact defect `rule.forbid.domain-term-synonyms` names, committed by the author of
the second reference to the first. it survived a syntax check, a push, and two live
applies, because a synonym breaks no runtime.

⇒ the lesson worth more than the word: **a synonym is invisible to every check this repo
runs.** the tests pass, the box converges, the verify goes green. it costs only the next
reader, who finds two names and has to work out whether they are two things.

## .evidence

### why the concept needs a name at all

it is load-bearing across a boundary. `5.12.rack` CREATES the directory and writes a
minimal `keyrack.yml` into it; `aws.reach.set` and `5.13.reach/configure.verify` READ
it. three files, one path, and a set/get pair that must agree — because a named-org
keyrack read is **cwd-sensitive**:

measured 2026-08-10, one box, one second apart: the same `keyrack get` returned
`ambient` from the scratch root and EMPTY from the dev-env-setup checkout, because a
named org resolves against a `keyrack.yml` in scope and that checkout declares
`env.camp` only.

⇒ so "which gitroot" is not an implementation detail. a verify that reads from the wrong
one reports a false ✋ against a correctly converged box
(`gotcha.a-check-that-cries-wolf-gets-silenced`).

### why the fallback is preferred and not mandatory

`$PWD` wins wherever it is already a repo, so a laptop run from a real checkout behaves
exactly as it did before the fallback existed. the scratch root is what a PUSHED tree
gets — and `grove.bootstrap.sh` names PUSHED as a legitimate provenance for `src`,
because that is how a branch is proven on a grove before it merges.

### why an EMPTY `git init` and not a clone

an earlier draft cloned dev-env-setup into this path. it failed on the first grove run:
the repo carries a `rhachet.use.ts` that imports `rhachet-roles-ehmpathy`, and a bare
clone has no `node_modules`, so `rhx` died in CONFIG LOAD before it ever reached
keyrack. an empty init carries no config for rhx to trip over.
