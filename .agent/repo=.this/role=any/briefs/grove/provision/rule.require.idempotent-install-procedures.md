# rule.require.idempotent-install-procedures

## .what

every phase the upgrade drives must be **idempotent** — a re-run converges to the same
machine state, with no duplicate effect and no harm. whatever the phase is named.

`src/grove.provision._.sh` is the one entrypoint, and it is meant to be re-run: that re-run
IS the upgrade path. so idempotency is the contract of every phase it drives.

**the entrypoint's NAME depends on this rule.** it is called `upgrade` because every
step converges; one step that does not makes the word a lie. see
`rule.require.grove-provision-as-the-only-entrypoint`, which binds the two together.

## .why

- **an upgrade is a re-run.** to upgrade a machine — local or a grove — you run the
  same procedure again. if a step is not idempotent, that re-run duplicates, corrupts,
  or clobbers, so the upgrade needs a human to babysit it and cannot be automated.
- **the runtime leans on it.** `src/bundle.upgrade.sh` names each phase's outcome and
  carries on past a failure, so a partial run is normal. the fix for a partial run is
  to re-run — which only works if every phase tolerates a re-run.
- **a bake is a re-run too.** an AMI bake, then a later config refresh onto the same
  box, hits the same procedures twice by design.
- **stacked appends are the classic defect.** an unguarded `>>` into an rc file adds
  its line on every run, so the tenth run has ten copies and a slow shell.

## .the shapes that are idempotent

| what the step does | the idempotent shape |
|---|---|
| install a package | `pkg_install <name>` — the package manager is already idempotent |
| install a pinned binary | fetch + verify + overwrite the same path; a re-fetch converges |
| copy a config | `cp src dest` — an unconditional overwrite IS an upsert |
| append a line to an rc file | **guard it**: `grep -q <line> <file> \|\| printf ... >> <file>` |
| clone a repo | guard on the dir: `[[ -d <dir> ]] \|\| git clone ...` |
| write a systemd unit | write the file, then `systemctl enable --now` (both idempotent) |
| switch the login shell | check the current shell first, or tolerate a no-op |
| create a dir | `mkdir -p` |

## .the shapes that are NOT

- `printf '...' >> ~/.zshrc` with no guard — stacks a line per run
- `git clone` with no dir guard — fails on the second run
- `useradd` / `ln -s` with no `-f` or no guard — fails on the second run
- a step that reads its own prior output as if absent
- a step that fails when what it installs is already present
- **a step that puts a question to a human.** it does not converge — it stops, and
  because a run's stdout is often a pipe, it stops with the question swallowed and no
  output to say why. `pnpm --version` hung 57 minutes on grove-1 this way, on
  corepack's `[Y/n]` prompt. the entrypoint declares `CI=1` and
  `DEBIAN_FRONTEND=noninteractive` once for the whole run

## .the test

> run the procedure twice in a row. is the machine in the same state, and did the
> second run report no error?

- yes → idempotent
- no → fix the step, not the caller

## .how to check it

```sh
# the whole tree, twice
rhx grove.provision --for cloud --mode apply
rhx grove.provision --for cloud --mode apply   # must report 0 failed

# one bundle, twice
rhx grove.provision --what 2.5.zsh --mode apply
rhx grove.provision --what 2.5.zsh --mode apply
```

⚠️ `--mode apply` is not optional in this check. `--mode plan` short-circuits every
`*.upsert`, so a plan run mutates no state — and a check that never mutates cannot tell you
whether a second mutation is safe. it would pass on a bundle that is wildly non-idempotent.

## .the stronger form — plan / apply / apply

the real proof is a **fixed point**: plan, apply, apply again, then plan once more and
require it to report no work owed. a `prove.bundles.plan-apply-apply` probe drives
exactly this across every leaf — see
`rule.require.prove-each-bundle-plan-apply-apply`.

## .the caveat — tolerated absence is not idempotency

a step may tolerate a genuinely absent package and still be idempotent: it converges to the
same state each run, and it NAMES the miss. `4.5.nvim` does exactly this —
`pkg_install imagemagick || echo "imagemagick absent — inline image render stays off"` —
because the editor is usable without the renderer, and a named degradation is a truthful
report.

what is forbidden is a step that *changes* state differently on the second run. and what is
forbidden separately is a miss that goes UNNAMED: a silent skip reads identically to a
success, so the roll would claim coverage the box does not have
(`rule.forbid.failhide`).

## .enforcement

- a phase that fails on a second run = **blocker**
- an unguarded append into an rc file, unit file, or config = **blocker**
- an unguarded `git clone`, `ln -s`, or create-shaped call = **blocker**

## .see also

- `rule.require.grove-provision-as-the-only-entrypoint` — the invariant this rule is
  clause 2 of: one entrypoint, an idempotent inventory, and the name that follows
- `rule.require.repo-as-source-of-truth` — why the repo drives machine state
- `rule.require.every-function-has-a-driver` — every declared function must be reached
- `rule.require.install-via-procedures` — never hand a human a one-off command
- `howto.provision-a-grove` — the re-run recovery path this rule makes safe
