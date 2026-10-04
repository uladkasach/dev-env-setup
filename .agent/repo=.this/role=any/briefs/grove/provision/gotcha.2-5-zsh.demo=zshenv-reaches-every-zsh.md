# demo: zshenv.sh — every measurement behind what `~/.zshenv` carries, and what it may not

## .what

`2.5.zsh/zshenv.sh` installs as `~/.zshenv`, the one startup file EVERY zsh reads. each
block in it was placed there by a measurement below; the file keeps the outline.

## m1 — `~/.zshrc` reaches an INTERACTIVE shell alone

```
zsh -ic  '…'   → .zshenv + .zshrc
zsh -c   '…'   → .zshenv only
sg docker -c   → .zshenv only
npm run / jest → .zshenv only
```

📜 2026-08-06: `AWS_PROFILE=ambient` was declared in `~/.zshrc`, and grove-1's integration
suite still died with `AWS_PROFILE not set`. the export was correct, present, and readable —
and the test process was a non-interactive shell that never sourced the file.

⇒ an env pointer a PROGRAM must read belongs in `.zshenv`. an rc is for a HUMAN's shell
(prompt, aliases, keybinds). a variable in the wrong one is not a smaller version of right —
it is absent exactly where it is needed.

## m2 — `~/.local/bin`: git execs its credential helper by NAME

📜 2026-08-10, grove-ahbode-v20260810 — `2.2.git.configure.verify`, over the duct:

```
✋ the helper is installed and current, but NOT on PATH
```

it was right. the file was present, executable, and byte-identical to the checkout, and
`~/.local/bin` reached PATH from `~/.zshrc` ALONE:

```
zsh -ic 'git fetch'     → .zshrc ran   → helper found
ssh grove 'git fetch'   → .zshenv only → helper ABSENT
a jest suite, a cron, a ci step        → helper ABSENT
```

git does not say "the helper is not on PATH" — it reports only that it could not
authenticate. the symptom is an auth failure and the cause is a shell file, two facts with
no visible link between them.

## m3 — `~/.cargo/bin`: nvim-treesitter EXECS `tree-sitter`

📜 2026-08-12: `~/.cargo/env` was sourced from `~/.zshrc` alone, so cargo's bin dir was
absent from every program-invoked shell, and every parser build over a duct failed on a box
whose `tree-sitter` was installed, executable, and current.

- the rc STATED the m1 rule ten lines above where it broke it — the third instance of that
  shape (AWS_PROFILE, the fnm/pnpm chain, cargo). a rule stated beside the code that violates
  it is a rule no reader catches (`gotcha.a-tool-found-by-path-answers-only-a-human`)
- the zshenv block restates the dir rather than sources `~/.cargo/env`, since that file
  re-exports PATH UNGUARDED and would grow it once per nested shell

## m4 — the node chain: a transport compensated for a PATH in the wrong file

📜 2026-08-12: with the chain in `~/.zshrc`, `rhx` (a pnpm global shim) was absent from every
program-invoked shell, and a one-command provision was impossible on the seat that does the
work. the cost was not one absent command — `git.grove.operations.sh:_shell_at` probed each
seat for a `~/.zshrc` and picked `zsh -ic` over `bash -lc` on that evidence. a workaround in
the transport is what a PATH claim in the wrong file costs.

### the fnm dir that holds BINARIES is `aliases/default/bin`

`$HOME/.local/share/fnm` is fnm's DATA dir: `aliases/` and `node-versions/`, and not one
executable. 📜 2026-08-12, with that dir named, `ssh <seat> 'command -v node'` stayed empty —
a PATH entry present, readable, and useless reads exactly like an absent export, so the
mistake survives an `echo $PATH` inspection.

- the interactive dir is EPHEMERAL: `eval "$(fnm env)"` mints a per-shell symlink dir
- `aliases/default/bin` is the one fnm path that outlives a shell, which is why
  `git-credential-keyrack.sh` already named it (git execs it with no shell at all)
- that dir carries `pnpm` too — corepack shims it there — so the fnm and pnpm blocks are not
  alternatives; a seat needs both
- `$FNM_DIR` is honored, since fnm relocates its data dir on it

## m5 — the fnm BINARY and `FNM_MULTISHELL_PATH`, issue #140

`eval "$(fnm env)"` sat on the "stays in `~/.zshrc`" list until 2026-09-19. the argument was
sound for the half it weighed — `fnm env` mints a PER-SHELL dir, so it looked like prompt
work. what it missed: `fnm use`, the command a repo's own build runs to honor `.nvmrc`,
CANNOT WORK without it.

📜 2026-09-19, a converged grove, from a NON-interactive zsh:

```
$ which node fnm pnpm
…/aliases/default/bin/node       ← ✔ the default/bin block
fnm not found                    ← ✋ half 1
…/aliases/default/bin/pnpm       ← ✔

$ PATH="$FNM_DIR:$PATH" fnm use  # half 1 forced on by hand
error: We can't find the necessary environment variables to replace
the Node version. You should setup your shell profile to evaluate `fnm env`
                                 ← ✋ half 2, still
```

- INVISIBLE from a keyboard: `~/.profile` carries both halves for a login bash and `~/.zshrc`
  for an interactive zsh, so a human finds a healthy box while every agent, cron, jest child
  and `zsh -c` dies at `fnm: command not found`
- found when `rhx declapract.upgrade exec` — whose `exec.sh:63` calls `fnm use` — died at
  step one

### the cost, against the file's own budget

the header bars "no command that costs more than a test", and this is the first line there
to FORK a binary. a scrubbed `zsh -c true` measured **17ms** with it, against a 400ms bound.
the bound is a CHECK, not a sentence: `prove.node-toolchain-reaches-a-noninteractive-zsh`,
arm 3.

### why the mint is GUARDED

`fnm env` mints a FRESH per-shell dir every call, and `.zshenv` runs on every nested zsh too —
unguarded, it forks once per nested shell and litters `/run/user` with a dir per shell.
guarded, a fresh shell mints its own (the isolation a per-shell dir exists for) and a nested
one inherits its parent's.

🛑 do NOT "simplify" to a hardcoded `FNM_MULTISHELL_PATH`. it is the workaround that first got
past #140, and it is wrong as a fix: a shared constant lets two concurrent shells fight over
ONE node version.

## m6 — the guard reads the PATH ENTRY, never the VAR alone

📜 2026-09-30. the var was the guard's first reader, and it is a PROXY for the fact the guard
needs — *is a usable multishell dir already reachable?* — and the two part company in one
REACHABLE state:

```
FNM_MULTISHELL_PATH set  ∧  "$FNM_MULTISHELL_PATH/bin" NOT on PATH
```

a parent that exports the var and rebuilds PATH without it leaves exactly that. the var-only
guard SKIPS the eval, and the next `fnm use` says so on stderr at every boot:

```
The current Node.js path is not on your PATH environment variable.
You should setup your shell profile to evaluate `fnm env` …
```

- found by `prove.rc-is-quiet-on-boot` arm 0b. a re-boot with the var scrubbed was QUIET,
  which parted the two subjects: healthy for a terminal, broken for a nested shell — and a
  human's every `$( )` is a nested shell (`gotcha.a-check-that-cries-wolf-gets-silenced`,
  m.4 — verdict right, subject named wrong)
- the litter reason is untouched: a properly nested shell carries BOTH the var and the PATH
  entry, so it still skips. only the half-set state re-evals, and that state is a defect
- `prove.fnm-guard-reads-the-path-not-the-var` holds it

## m7 — BOTH `$PNPM_HOME` and `$PNPM_HOME/bin`, and the order is a tiebreak

pnpm treats `$PNPM_HOME` as the global bin dir in some versions and a `/bin` child in others;
corepack reports the child. name both, and neither refuses.

`/bin` is prepended LAST so it lands FIRST. one command can have two shims, and the stale one
hardcodes a NODE_PATH at the old store layout. 📜 grove-1, 2026-08-03: two shells disagreed
about which `rhx` they meant — zsh ran, bash died with `Cannot find module
'with-simple-cache'`. `5.1.node/provision.upsert.sh` carries the same pair in the same order
(`rule.forbid.two-writers-on-one-artifact`).

## m8 — `AWS_SDK_LOAD_CONFIG=1` reads `~/.aws/credentials` UNCONDITIONALLY

aws-sdk v2's `Config.region` getter (`node_loader.js:100`) derives the region from the shared
ini files, and its loader opens the credentials file whether or not a profile needs it — an
ABSENT `~/.aws/credentials` throws `ENOENT … open '~/.aws/credentials'`. a laptop always has
that file. a grove does not: `5.6.aws.configure` writes `~/.aws/config` alone, since an
ambient identity is a POINTER and never a stored key. that phase findserts an EMPTY
credentials file for this reason, and its verify owns the claim.

## m9 — `AWS_PROFILE` is DELIBERATELY not exported, removed 2026-08-08

the file exported `AWS_PROFILE=ambient` for two days. it fixed one defect and caused a worse
one, for a reason in one line of rhachet's type doc:

```
KeyrackHostVault.d.ts — "os.envvar is always checked first in grant flow (ci passthrough)"
```

so an exported `AWS_PROFILE` OUTRANKS EVERY RACK ENTRY, for every org and every env. 📜
grove-1, 2026-08-08, after `aws.reach.set` had written and PROVEN the prep hop:

```
rack    ahbode.test.AWS_PROFILE = "ambient"                  ← read off the ENV
profile ahbode.test.ehmpath     = …<prep-acct>:…/<prep-oidc-role> ✔
suite   all 44 refusals         = …<camp-acct>:…/<camp-grove-role>
```

the hop worked. no consumer could name it, because one shell variable answered for all
four envs.

⇒ the box's identity is a RACK fact (`<org>.camp.AWS_PROFILE = ambient`), and so is each
per-env identity. the ORIGINAL defect is answered by the rack (`keyrack.source()` sets
`AWS_PROFILE` per env) and by `[default]` in `~/.aws/config` from `5.6.aws`. if `AWS_PROFILE
not set` returns, the fix is a rack entry for that org+env — never an export here, which
would silently disable every other env on the box.

## .see also

- `2.5.zsh/zshenv.sh` — the file these measurements back
- `howdoes.a-box-reach-an-aws-account.md`, failure 4 — m9 in its larger frame
- `gotcha.a-tool-found-by-path-answers-only-a-human` — m1–m5's shared shape
- `prove.node-toolchain-reaches-a-noninteractive-zsh` · `prove.fnm-guard-reads-the-path-not-the-var`
