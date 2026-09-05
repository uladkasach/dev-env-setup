# domain.term.choice.reason: bootstrap (in `grove.bootstrap`)

## .etymology

the word is the old idiom — to pull oneself up by one's own bootstraps — and it is exact here,
because the circularity is the whole problem:

```
run the installer  →  the installer lives in the repo  →  need the repo  →  need the installer?
```

a bootstrap is precisely the artifact that escapes a circle of that shape. no other candidate word
carries that sense; each of the rejected ones names a *phase* or a *start*, not an escape.

the term was born 2026-07-26, when the human asked what a human at `github.com` copy-pastes on a
machine that has no repo yet. that question exposed three stacked defects (below), and the answer
needed a name.

## .why not the rejected words

| rejected | why it fails |
|---|---|
| `entrypoint` | **already taken.** `grove.provision._.sh` is declared THE entrypoint, and its singularity is load-bear. a second entrypoint makes "which one?" permanent |
| `init` | claims to initialize the *env*, which is `grove.provision`'s job. it also collides with `keyrack init` / `git init` vocabulary |
| `setup` | the vaguest candidate — it could name any of fetch, install, or config. the repo is literally called dev-env-**setup**, so the word already names the WHOLE, not this part |
| `installer` | it installs no config and no tool; it fetches a repo and hands off. to call it an installer would misdescribe it and shadow `grove.provision` |
| `prelude` / `preinstall` | both define the artifact by what follows it rather than what it does. and `pre*` invites a `post*` that has no reason to exist |
| `onboard` | about a human who joins a team, not a machine that acquires a repo |

## .disputes

### dispute: a bare `bootstrap.sh` filename — raised 2026-07-26 — status: RESOLVED (prefix the file too)
- raised.by  = \<human\>
- claim      = if the prefix is the correct term, rename the file now rather than wait.
- counter    = my first draft left the file bare and deferred the rename behind a trigger —
               *"the moment a second bootstrap exists"* — on the argument that the root of
               **dev-env-setup** already supplies the context, the same allowance the glossary
               readme grants a domain object itself (`grove`, `tree`).
- resolution = **the human was right, and the deferral was the error.** the argument for a bare
               file was true but beside the point. the trigger i named would fire *after*
               `readme.md` publishes the raw url — so the future rename would break a url that
               humans had already copied and bookmarked. that makes the later rework **not
               clean**, which is precisely the condition under which a fulcrum must be decided
               now rather than flagged for later
               (`howto.navigate-fulcrum-choices`: defer only when the rework stays clean).
               renamed to `grove.bootstrap.sh` while the cost was four references and zero
               published urls.

### the lesson, distinct from the rename
a deferral is only free when the *cost curve is flat*. i checked whether the rework would be
mechanically simple (a rename — yes) and failed to check whether it would still be **cheap at the
moment the trigger fires**. a trigger that fires after publication is a trigger that fires too
late. so: before you defer, ask not only *"is this reversible?"* but *"is it reversible AT THE
TIME this trigger fires?"*

that is the same defect shape as `rule.require.exemptions-name-their-trigger` — a written
carve-out that reads as considered while the reason under it does not hold.

## .a residual, recorded rather than hidden
the repo's other files do **not** follow term names: the file is `src/install_env._.sh` while the
term is `grove.provision`. so `grove.bootstrap.sh` is currently the only file named after its
term.

that inconsistency is accepted, not overlooked: the `install_env.*` files form a family inside
`src/`, where the directory supplies context; `grove.bootstrap.sh` stands alone at root, where a
`grove.bootstrap` would also land. if the `install_env.*` family is ever renamed to match its
term, this file is already in the right shape.

## .evidence

the term earned itself by exposure of three defects that had stacked unnoticed:

1. **`clone_this_repo` was dead code that LOOKED load-bear.** declared in
   `install_env.pt2.shell.sh`, driven by no `step` line, and named such that a reader would trust
   it as the way the repo reached a new machine. it could never work: to call it you must have
   sourced the file that contains it (so you already have the repo), and it cloned over **ssh**,
   which no fresh machine can do — `install_ssh` runs later, and its pubkey needs a human at a
   browser.
2. **`readme.md` was one line, with zero commands.** it is the human's entrypoint whether or not
   we design for it, because github renders it on the repo's front page. a
   `rule.require.discoverability` blocker in the most-read file of the repo.
3. **the inline clone guard tested a hardcoded path**, not whether the sources were complete — so
   a checkout at `~/code/dev-env-setup`, or a pushed worktree, took its configs from `BOOT_DIR`
   **and** cloned a redundant second tree at `~/git/more/dev-env-setup`. two trees, silently
   divergent (`rule.require.solve-at-cause`).

the term also forced a fix to a **rule**: `rule.require.every-function-has-a-driver` had said
"`install_*` / `configure_*`", and `clone_this_repo` walked through that gap. a prefix list gave
**false confidence rather than none** — the rule read as complete while it exempted every other
verb. it now covers any function in a `pt*.sh` file, and grants `grove.bootstrap.sh` the single explicit
exemption, since a bootstrap cannot be a step of the run it starts.

one property this term must keep honest: `grove.bootstrap.sh` **duplicates** the package-manager detect
from `install_env.pkg.sh`. that is unavoidable, not sloppy — the shim lives in the repo the
bootstrap exists to fetch. the duplication covers exactly one install (git), and the file says so.
